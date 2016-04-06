for test_app <- [:gproc, :cowboy, :phoenix] do
  {:ok, _} = Application.ensure_all_started(test_app)
end

ExUnit.start()
