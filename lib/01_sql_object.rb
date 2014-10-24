require_relative 'db_connection'
require 'active_support/inflector'

# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject  
  def self.columns  
    table = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM 
        #{self.table_name}
      SQL
      
    table[0].map { |col| col.to_sym }
  end

  def self.finalize!
    self.columns.each do |col|
      define_method("#{col}") { attributes[col] }
      define_method("#{col}=") { |val| attributes[col] = val }
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    table_name = ""

    self.to_s.split('').each do |letter|
      if letter =~ /[A-Z]/
        table_name << "_#{letter.downcase}"
      else
        table_name << letter
      end
    end

    @table_name ||= (table_name[1..-1] + "s")
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
    SELECT
      *
    FROM
      #{table_name}
    SQL
    
    parse_all(results)
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id)
    SELECT
      *
    FROM 
      #{table_name}
    WHERE 
      id = ?
    LIMIT
      1
    SQL
    
    parse_all(result).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      if self.class.columns.include?(attr_name.to_sym)
        self.send("#{attr_name}=", value)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map{ |attr_name| self.send(attr_name) }
  end

  def insert
    col_names = self.class.columns.join(", ")
    num_cols = self.class.columns.length
    question_marks = ("?, " * num_cols)[0..-3]
    DBConnection.execute(<<-SQL, *attribute_values)
    INSERT INTO
      #{self.class.table_name} (#{col_names})
    VALUES
      (#{question_marks})
    SQL
    
    new_id = DBConnection.last_insert_row_id
    self.send("id=", new_id)
  end

  def update
    things_to_set = self.class.columns.map { |attr_name| "#{attr_name} = ?" }
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
    UPDATE
      #{self.class.table_name}
    SET
      #{things_to_set.join(", ")}
    WHERE
      id = ?
    SQL
  end

  def save
    self.id.nil? ? insert : update
  end
end
