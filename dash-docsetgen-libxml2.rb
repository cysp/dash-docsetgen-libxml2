#!/usr/bin/env ruby

require 'nokogiri'
require 'sqlite3'


filenames = Dir.glob('libxml-*.html')

db = SQLite3::Database.new('libxml2.docset/Contents/Resources/docSet.dsidx')
db.execute('CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)')
db.execute('CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)')
db_stmt = db.prepare('INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES (:name, :type, :path)')

filenames.each do |filename|
  i = IO.read(filename)
  d = Nokogiri::XML.parse(i)
  h3_nodes = d.xpath('//h:h3/h:a[@name]/..', 'h' => 'http://www.w3.org/1999/xhtml')

  h3_nodes.each do |h3_node|
    a_node = h3_node.first_element_child
    identifier = a_node.attribute('name').value
    h3_content = h3_node.content

    case h3_content
    when /^Enum (.*)/
      db_stmt.execute(name: $1, type: 'Enum', path: '%s#%s' % [filename, identifier])
    when /^Structure (.*)/
      db_stmt.execute(name: $1, type: 'Struct', path: '%s#%s' % [filename, identifier])
    when /^Macro: (.*)/
      db_stmt.execute(name: $1, type: 'Macro', path: '%s#%s' % [filename, identifier])
    when /^Function: (.*)/
      db_stmt.execute(name: $1, type: 'Function', path: '%s#%s' % [filename, identifier])
    when /^Function type: (.*)/
      db_stmt.execute(name: $1, type: 'Type', path: '%s#%s' % [filename, identifier])
#    else
#      $stdout.print identifier, ': ', h3_node.content, "\n"
    end
  end
end
