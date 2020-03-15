### Project goal: learning to learn!
#### It's hard to interlalize documentation, this is my first attempt to do it. Elixir documentation is great, but it's a tough read.

#### Approach
- simplify explanations by writing in own words
- remove :hibernate/Distribution/Hot code reloading clutter
- organize functions/callbacks logically
- make small flow diagrams
- try to focus on big picture, but not ignore anything relevant
- for each OTP Behaviour, do: description->code examples->callbacks->functions
- reduce duplication. For example GenStage has Reply same as GenServer. Just point to GenServer for details.

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