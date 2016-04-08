defmodule Example.Router do
  use Example.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", Example do
    pipe_through :api
  end
end
