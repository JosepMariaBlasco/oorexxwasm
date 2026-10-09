/* Files live in memory, in /home/rexx.  What a program writes stays      */
/* there for the next runs (see "files" below the console), until you     */
/* press "Clear files".                                                   */
file = "notes.txt"
if stream(file, "c", "query exists") = "" then do
  say "First run: creating" file
  call lineout file, "created" date() time()
end
else do
  say file "already exists; it has" lines(file, "c") "lines:"
  do while lines(file) > 0
    say "  " linein(file)
  end
end
call lineout file, "run at" time("L")
call lineout file
say "Run me again."
