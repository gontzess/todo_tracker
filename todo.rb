require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret' ## normally wouldn't store env variable in code
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

after do
  @storage.disconnect
end

helpers do
  ## checks if all todos in the list are completed
  def list_complete?(list)
    list[:todos_count] > 0 && list[:todos_remaining_count] == 0
  end

  ## class styling for todo lists
  def list_class(list)
    "complete" if list_complete?(list)
  end

  def sort_lists(lists, &block)
    complete, incomplete = lists.partition { |list| list_complete?(list) }

    incomplete.each(&block)
    complete.each(&block)
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }

    incomplete.each(&block)
    complete.each(&block)
  end
end

def load_list(list_id)
  found_list = @storage.find_list(list_id)
  return found_list if found_list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

## return an error message if the name is invalid. return nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

## return an error message if the name is invalid. return nil if name is valid
def error_for_todo_name(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  redirect "/lists"
end

## view list of lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

## render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

## create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

## view an existing list and it's todos
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todos = @storage.find_todos_for_list(@list_id)

  erb :list, layout: :layout do
    erb :new_todo
  end
end

## edit an existing todo list
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  erb :edit_list, layout: :layout
end

## update an existing todo list
post "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

## delete an existing todo list
post "/lists/:list_id/delete" do
  @list_id = params[:list_id].to_i

  @storage.delete_list(@list_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

## update all todos in a list to complete
post "/lists/:list_id/complete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_todos_as_complete(@list_id)

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end

## create a new todo task
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_name = params[:todo_name].strip
  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout do
      erb :new_todo
    end
  else
    @storage.create_new_todo(@list_id, todo_name)
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

## delete an existing todo task
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @storage.delete_todo_from_list(@list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

## update the status of an existing todo task
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end
