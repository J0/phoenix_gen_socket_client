defmodule ExampleWeb.Router do
  use ExampleWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ExampleWeb do
    pipe_through :api
  end
end
