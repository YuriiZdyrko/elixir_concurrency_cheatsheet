## Application configuration

```elixir
# config.exs
import Config

config :some_app,
  key1: "value1",
  key2: "value2"

import_config "#{Mix.env()}.exs"

# Usage
"value1" = Application.fetch_env!(:some_app, :key1)
```

### Config.Provider behaviour
Specifies a provider API that loads configuration during boot.
Config providers are typically used during releases to load external configuration while the system boots.
Results of the providers are written to the file system.

```elixir
defmodule JSONConfigProvider do
  @behaviour Config.Provider

  # Let's pass the path to the JSON file as config
  def init(path) when is_binary(path), do: path

  def load(config, path) do
    # We need to start any app we may depend on.
    {:ok, _} = Application.ensure_all_started(:jason)

    json = path |> File.read!() |> Jason.decode!()

    Config.Reader.merge(
      config,
      my_app: [
        some_value: json["my_app_some_value"],
        another_value: json["my_app_another_value"],
      ]
    )
  end
end

# mix.exs -> :releases
releases: [
  demo: [
    # ...,
    config_providers: [{JSONConfigProvider, "/etc/config.json"}]
  ]
]
```

Functions:
```elixir
resolve_config_path!(config_path()) :: path
validate_config_path!(config_path()) :: :ok
    config_path() :: 
        {:system, env_value_key, path}
        | path

# Example:
System.put_env("BLAH", "blah")
resolve_config_path!({:system, "BLAH", "/rest"})
# => "blah/rest"
```

Callbacks:
```elixir
init(term()) :: state()
```
Invoked when initializing a config provider.

A config provider is typically initialized on the machine where the system is assembled and not on the target machine. The `init/1` callback is useful to verify the arguments given to the provider and prepare the state that will be given to load/2.

Furthermore, because the state returned by `init/1` can be written to text-based config files, it should be restricted only to simple data types, such as integers, strings, atoms, tuples, maps, and lists. Entries such as PIDs, references, and functions cannot be serialized.


```elixir
load(config(), state()) :: config()
```
Loads configuration (typically during system boot).

It receives the current config and the state returned by init/1. Then you typically read the extra configuration from an external source and merge it into the received config. Merging should be done with `Config.Reader.merge/2`, as it performs deep merge. It should return the updated config.

Note that `load/2` is typically invoked very early in the boot process, therefore if you need to use an application in the provider, it is your responsibility to start it.

### Config.Reader

API for reading config files defined with Config.
Can also be used as a Config.Provider:
```elixir
# mix.exs
releases: [
  demo: [
    # ...,
    config_providers: 
        [{Config.Reader, "/etc/config.exs"}]
        | [{Config.Reader, {:system, "RELEASE_ROOT", "/config.exs"}}]
  ]
]
```

**mix release**
By default Mix releases supports runtime configuration via a `config/releases.exs`. If a `config/releases.exs` exists in your application, it is automatically copied inside the release and automatically set as a config provider.

Functions:
```elixir
merge(config1:keyword(), config2:keyword())

read!(file, imported_paths \\ [])
# Reads configuration file.
# Example: mix.exs:releases config in a separate file.
releases: Config.Reader.read!("rel/releases.exs")

read_imports!(file, imported_paths \\ [])
# Reads configuration file and it's imports.
```