## Mix release

Assembles a self-contained release for the current project.
Benefits:
- Code preloading
- Configuration and customization of system and VM
- Self-contained, includes ERTS and stripped versions of Erlang and Elixir 
- Scripts to start, restart, connect to the running system remotely, execute RPC calls, run as daemon

```elixir
MIX_ENV=prod mix release # relies  on default_release: NAME
MIX_ENV=prod mix release NAME
```

Build/deploy environment must have same OS distribution and versions.

### Release configuration

By default `:applications` includes the current application and all applications the current application depends on, recursively.

```elixir
def project do
  [
    releases: [
      demo: [
        include_executables_for: [:unix],
        applications: [
            runtime_tools: application_option()
        ],

        config_providers: list \\ [],
        strip_beams: bool \\ true,
        path: path \\ "_build/MIX_ENV/rel/RELEASE_NAME",
        version: version \\ current_app_version,
        include_erts: bool \\ true,
        include_executables_for: [:unix | :windows] \\ []
        overlays: overlays(),
        steps: steps()
      ],

      ...
    ]
  ] 

  # Release config can be passed a function
  | releases: [
    demo: fn ->
      [version: @version <> "+" <> git_ref()]
    end
  ]
end

application_option() \\ :permanent
  :permanent
  # application is started and the node shuts down 
  # if the application terminates, regardless of reason
  :transient 
  # application is started and the node shuts down 
  # if the application terminates abnormally
  :temporary
  # application is started and the node does not shut down 
  # if the application terminates
  :load 
  # the application is only loaded
  :none
  # the application is part of the release but it is neither loaded nor started

overlays() \\ "rel/overlays"
# Directory for extra files to be copied into root folder of release.

steps() \\ [:assemble]
# Dynamically build Release struct:

releases: [
  demo: [
    steps: [&set_configs/1, :assemble, &copy_extra_files/1]
  ]
]
```

### Application configuration
Releases provides two mechanisms for configuring OTP applications: build-time and runtime.

#### App configuration: build-time
```elixir
# config/config.exs, config/prod.exs...
import Config
config :my_app, 
  :secret_key, 
  System.fetch_env!("MY_APP_SECRET_KEY")
```

- evaluated during code compilation or release assembly

#### App configuration: run-time
**1. Using runtime configuration file (`releases.exs` by default)**
```elixir
# `config/releases.exs`
import Config
config :my_app, 
  :secret_key, 
  System.fetch_env!("MY_APP_SECRET_KEY")
```

- evaluated early during release start
- writes computed configuration to `RELEASE_TMP` (by default `$RELEASE_ROOT/tmp`) folder
- restarts release

Rules for runtime configuration file:
- It MUST import Config at the top instead of the deprecated use Mix.Config
- It MUST NOT import any other configuration file via import_config
- It MUST NOT access Mix in any way, as Mix is a build tool and it not available inside releases

**2. Using config providers**

- loads configuration during release start, using custom mechanism, for example read JSON file, or access a vault
- writes computed configuration to `RELEASE_TMP` (by default `$RELEASE_ROOT/tmp`) folder
- restarts release

```elixir
# mix.exs
releases: [
  demo: [
    # ...,
    config_providers: [{JSONConfigProvider, "/etc/config.json"}]
  ]
]
```

### VM and environment configuration
```elixir
mix release.init

* creating rel/vm.args.eex
* creating rel/env.sh.eex
* creating rel/env.bat.eex

# In those files following variables can be used:
RELEASE_NAME, 
RELEASE_COMMAND (start, remote, eval...), 
RELEASE_VSN, 
RELEASE_ROOT
```

#### Interacting with a release

```elixir
# Start system
_build/prod/rel/my_app/bin/my_app start

# Stop system (vm, app and supervision trees in opposite to starting order)
Send SIGINT/SIGTERM to OS process
| bin/RELEASE_NAME stop
```

```elixir
# One-off commands

defmodule MyApp.ReleaseTasks do
  def eval_purge_stale_data() do
    Application.ensure_all_started(:my_app)

    # Code that purges stale data
  end
end

# >
bin/RELEASE_NAME eval "MyApp.ReleaseTasks.eval_purge_stale_data()"
bin/RELEASE_NAME rpc "IO.puts(:hello)"
```

```elixir
# All commands (`bin/RELEASE_NAME` help)

start          Starts the system
start_iex      Starts the system with IEx attached
daemon         Starts the system as a daemon
daemon_iex     Starts the system as a daemon with IEx attached
eval "EXPR"    Executes the given expression on a new, non-booted system
rpc "EXPR"     Executes the given expression remotely on the running system
remote         Connects to the running system via a remote shell
restart        Restarts the running system via a remote command
stop           Stops the running system via a remote command
pid            Prints the operating system PID
               of the running system via a remote command
version        Prints the release name and version to be booted
```