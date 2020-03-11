This is detailed, but distilled version of Elixir->PROCESSES & APPLICATIONS documentation. 

Cheatsheet covers most important OTP-compliant abstractions, as well as `mix release` command.

I omitted all things related to Distribution and Hot code upgrades.

In case you want to generate your own `cheatsheet.md`:
```sh
cd "./practice" && iex -S mix
iex> Practice.ConcatMd.run()

=>
Copying ../theory/process.md
Copying ../theory/gen_server.md
Copying ../theory/supervisor.md
Copying ../theory/dynamic_supervisor.md
Copying ../theory/registry.md
Copying ../theory/task.md
Copying ../theory/task_supervisor.md
Copying ../theory/config.md
Copying ../theory/mix_release.md

../cheatsheet.md generated!
```
This will re-build `cheatsheet.md`.

Use online tool to convert .md to .pdf: 
https://md2pdf.netlify.com/