require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret' ## normally wouldn't store env variable in code
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  ## count total number of todos in a list
  def total_todos(list)
    list[:todos].size
  end

  ## count total number of uncompleted todos in a list
  def total_remaining_todos(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  ## checks if all todos in the list are completed
  def list_complete?(list)
    !list[:todos].empty? && total_remaining_todos(list).zero?
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

## return an error message if the name is invalid. return nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

## return an error message if the name is invalid. return nil if name is valid
def error_for_todo_name(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

def next_element_id(elements)
  max = elements.map { |element| element[:id] }.max || 0
  max + 1
end

def load_list(list_id)
  found_list = session[:lists].find { |list| list[:id] == list_id }
  return found_list if found_list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

get "/" do
  redirect "/lists"
end

## view list of lists
get "/lists" do
  @lists = session[:lists]
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
    list_id = next_element_id(session[:lists])
    session[:lists] << { id: list_id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

## view an existing list and it's todos
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

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
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

## delete an existing todo list
post "/lists/:list_id/delete" do
  @list_id = params[:list_id].to_i

  session[:lists].delete_if { |list| list[:id] == @list_id }
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

  @list[:todos].each { |todo| todo[:completed] = true }
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
    todo_id = next_element_id(@list[:todos])
    @list[:todos] << { id: todo_id, name: todo_name, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

## delete an existing todo task
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_if { |todo| todo[:id] == todo_id }
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
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }

  todo[:completed] = params[:completed] == "true"
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end
