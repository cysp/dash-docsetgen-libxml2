#!/usr/bin/env ruby

require 'fileutils'
require 'nokogiri'
require 'pathname'
require 'plist'
require 'sqlite3'


contents_path = Pathname.new('libxml2.docset/Contents')
resources_path = contents_path + 'Resources'
documents_path = resources_path + 'Documents'
FileUtils.mkdir_p documents_path

FileUtils.cp 'up.png', documents_path
FileUtils.cp 'right.png', documents_path
FileUtils.cp 'left.png', documents_path
FileUtils.cp 'home.png', documents_path

plist_hash = {
  CFBundleIdentifier: 'libxml2',
  CFBundleName: 'libxml2',
  DocSetPlatformFamily: 'libxml2',
  isDashDocset: true,
  dashIndexFilePath: 'index.html',
  DashDocSetFamily: 'dashtoc',
}
plist_path = contents_path + 'Info.plist'
IO.write plist_path, plist_hash.to_plist

filenames = Dir.glob('libxml-*.html') + ['index.html']

db = SQLite3::Database.new((resources_path + 'docSet.dsidx').to_s)
db.execute('CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)')
db.execute('CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)')
db_stmt = db.prepare('INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES (:name, :type, :path)')

filenames.each do |filename|
  module_name = nil
  case filename
  when /^libxml-(.*)\.html/
    module_name = $1
  end

  i = IO.read(filename)
  d = Nokogiri::XML.parse(i)
  h3_nodes = d.xpath('//h:h3/h:a[@name]/..', 'h' => 'http://www.w3.org/1999/xhtml')

  if h3_nodes.count && !module_name.nil? then
    db_stmt.execute(name: module_name, type: 'Module', path: filename)
  end

  h3_nodes.each do |h3_node|
    a_node = h3_node.first_element_child
    identifier = a_node.attribute('name').value
    h3_content = h3_node.content

    dash_type = nil
    dash_name = nil;
    case h3_content
    when /^Enum (.*)/
      dash_type = 'Enum'
      dash_name = $1;
    when /^Structure (.*)/
      dash_type = 'Struct'
      dash_name = $1;
    when /^Macro: (.*)/
      dash_type = 'Macro'
      dash_name = $1;
    when /^Function: (.*)/
      dash_type = 'Function'
      dash_name = $1;
    when /^Function type: (.*)/
      dash_type = 'Type'
      dash_name = $1;
#    else
#      $stdout.print identifier, ': ', h3_node.content, "\n"
    end

    if !dash_type.nil? && !dash_name.nil? then
      db_stmt.execute(name: dash_name, type: dash_type, path: '%s#%s' % [filename, identifier])
      h3_node.prepend_child('<a name=\'//apple_ref/cpp/%s/%s\' class=\'dashAnchor\'/>' % [dash_type, identifier])
    end
  end

  body_node = d.xpath('/h:html/h:body', 'h' => 'http://www.w3.org/1999/xhtml').first
  good_table_node = d.xpath('/h:html/h:body/h:table[position()=2]/h:tr/h:td/h:table/h:tr/h:td[position()=2]/h:table', 'h' => 'http://www.w3.org/1999/xhtml').first
  body_node.children = good_table_node unless good_table_node.nil?

  output_path = documents_path + filename
  o = File.open(output_path, 'w')
  d.write_xhtml_to o
end
