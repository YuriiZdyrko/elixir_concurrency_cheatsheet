In case you want to generate your own `cheeatsheet.pdf`:
```sh
cd "../practice" && iex -S mix
iex> Practice.ConcatMd.run()

=>
Copying ../theory/process.md
Copying ../theory/gen_server.md
Copying ../theory/supervisor.md
Copying ../theory/dynamic_supervisor.md
Copying ../theory/registry.md
Copying ../theory/task.md
Copying ../theory/task_supervisor.md
Copying ../theory/mix_release.md

../theory/cheatsheet.md generated!
```
This will re-build `/theory/cheatsheet.md`.
Use online tool to convert .md to .pdf: 
https://md2pdf.netlify.com/