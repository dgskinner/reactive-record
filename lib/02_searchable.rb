require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_line = params.keys.map { |key| "#{key} = ?" }
    values = params.values
    results = DBConnection.execute(<<-SQL, *values)
    SELECT
      *
    FROM
      #{table_name}
    WHERE
      #{where_line.join(" AND ")}
    SQL
    
    results.map { |result| self.new(result) }
  end
end

class SQLObject
  extend Searchable
end