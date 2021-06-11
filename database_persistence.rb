require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def find_list(list_id)
    sql = <<~SQL
      SELECT lists.*,
        count(todos.id) AS todos_count,
        count(nullif(todos.completed, true)) AS todos_remaining_count
        FROM lists
        LEFT JOIN todos ON todos.list_id = lists.id
        WHERE lists.id = $1
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL
    lists_result = query(sql, list_id)
    tuple_to_list_hash(lists_result.first)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
        count(todos.id) AS todos_count,
        count(nullif(todos.completed, true)) AS todos_remaining_count
        FROM lists
        LEFT JOIN todos ON todos.list_id = lists.id
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL
    lists_result = query(sql)
    lists_result.map { |list_tuple| tuple_to_list_hash(list_tuple) }
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name)
  end

  def update_list_name(list_id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2;"
    query(sql, new_name, list_id)
  end

  def delete_list(list_id)
    sql = "DELETE FROM lists WHERE id = $1;"
    query(sql, list_id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2);"
    query(sql, todo_name, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3;"
    query(sql, new_status, todo_id, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2;"
    query(sql, todo_id, list_id)
  end

  def mark_all_todos_as_complete(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1;"
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end

  def find_todos_for_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1;"
    todos_result = query(sql, list_id)

    todos_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i,
        name: todo_tuple["name"],
        completed: todo_tuple["completed"] == "t" }
    end
  end

  private

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def tuple_to_list_hash(list_tuple)
    { id: list_tuple["id"].to_i,
      name: list_tuple["name"],
      todos_count: list_tuple["todos_count"].to_i,
      todos_remaining_count: list_tuple["todos_remaining_count"].to_i }
  end
end
