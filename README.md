### Project description

It's hard to interlalize documentation, this is my first attempt to do it.

This is detailed, but distilled version of docs: 
- Elixir:Processes & Applications
- GenStage
- mix release

### Approach
- make explanations shorter
- use pseudo-code instead of wordy explanations if possible
- skip :hibernate/Distribution/Hot code reloading mentions for now
- document callbacks/functions in a logical order
- for each OTP Behaviour, cover in order: 
    - description
    - code examples
    - callbacks
    - functions
- reduce duplication. For example GenStage has Reply same as GenServer. Just point to GenServer for details

### Script to combine all files into `cheatsheet.md`
To put all separate *.md files into single `cheatsheet.md`:
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