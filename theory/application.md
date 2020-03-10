### Application

Applications are the idiomatic way to package software in Erlang/OTP.
Application = code + environment variables.
Applications can be loaded, started and stopped.

```elixir
# Run-time environment
defmodule MyApp.DBClient do
  def start_link() do
    SomeLib.DBClient.start_link(host: db_host())
  end

  defp db_host do
    Application.fetch_env!(:my_app, :db_host)
  end
end

# Compile-time environment (rarely used)
defmodule MyApp.DBClient do
  @db_host Application.compile_env(:my_app, :db_host, "db.local")

  def start_link() do
    SomeLib.DBClient.start_link(host: @db_host)
  end
end
```

#### Application start
- manual
``` elixir 
{:ok, _} = 
    Application.ensure_all_started(:some_app)
```

- automatic
```elixir
# mix.exs
def application do
  [mod: {MyApp, []}]
end

# application.ex
defmodule MyApp do
  use Application

  def start(_type, _args) do
    children = []
    Supervisor.start_link(
        children, 
        strategy: :one_for_one
    )
  end
end
```

### Application start
```
using mix
| Application.ensure_all_started(app)
| Application.start(app)
```

Prerequisite: application must be compiled
- invoke `Application.load/1` to merge `:env` and `config.exs`
- invoke `start/2` callback

### Application stop

```
# shuts down applications in opposite to starting order
System.stop(status \\ 0)

# shuts down top-most application
| Application.stop(app)
```

- invoke optional `prep_stop/1` callback
- terminate the top-level supervisor
- invoke `stop/1` callback

### mix.exs application options

- `:mod` - Application implementation module to invoke during Application start.
Example: `mod: {MyApp, []}`

- `:applications` - runtime dependencies, automatically inferred from :deps.
Started before the application itself.

- `:extra_applications` - runtime dependencies, which are not included in :deps. 
For example, applications that ship with Erlang/OTP or Elixir, like `:crypto` or `:logger`, but anything in the code path works.
Started before the application itself.

- `:included_applications` - applications with supervision trees started inside main application.

- `:registered` - names of all registered processes in the application, used for detecting conflicts between applications that register the same names. 
For example `[MyGenServer, MySupervisor]`.

- `:env` - the default values for the application environment.

- `:start_phases` - do work in synchronized steps during startup of main and included applications.

During compilation, Application resource file `APP_NAME.app` is generated for each app in a mix project.
It's values can be inspected usin Application.spec/1

```erlang
[
  description: 'practice',
  id: [],
  vsn: '0.1.0',
  modules: [Practice, Practice.Application, Practice.Async,
   Practice.AsyncStream],
  maxP: :infinity,
  maxT: :infinity,
  registered: [],
  included_applications: [],
  applications: [:kernel, :stdlib, :elixir, :logger],
  mod: {Practice.Application, []},
  start_phases: :undefined
]
```


### Functions

```elixir

### Utility

started_applications(timeout \\ 5000)
# Information about the running applications

app_dir(app)
app_dir(app, path)
spec(app)
spec(app, key)

###  Environment

# Get compile-time value (rarely used)
compile_env(app, key_or_path, default \\ nil)
compile_env!(app, key_or_path)

# Get run-time value
get_env(app, key, default \\ nil)
fetch_env(app, key)
fetch_env!(app, key)

delete_env(app, key, opts \\ [])
put_env(app, key, value, opts \\ [])
# opts: 
#    :timeout \\ 5000 - timeout for the change
#    :persistent - persist between application loads

### Starting/stopping

ensure_all_started(app, type \\ :temporary)
# Ensures the given app and its applications are started.

start(app, type \\ :temporary)
stop(app)
```

### Callbacks
```elixir
start/2
# Called when an application is started.

start_phase/3
# Called after start/2 finishes but before Application.start/2 returns

prep_stop/1
# Called before stopping the application.

stop/1
# Called after an application has been stopped.
```