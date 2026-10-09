/* Real threads: each START runs a method on its own thread (a Web        */
/* Worker here), and GUARD WHEN makes a thread wait for a condition.      */
counter = .Counter~new
do i = 1 to 4
  .Worker~new~start("run", i, counter)
end
say "main: started 4 workers, waiting for them..."
counter~waitFor(4)
say "main: all workers done, total =" counter~total

::class Worker
::method run
  use arg n, counter
  do step = 1 to 3
    call SysSleep random(1, 30) / 100
    say "  worker" n "step" step
  end
  counter~add(n * 100)

::class Counter
::attribute total get
::method init
  expose total done
  total = 0; done = 0
::method add
  expose total done
  use arg amount
  total += amount; done += 1
::method waitFor
  expose done
  use arg n
  guard on when done >= n
