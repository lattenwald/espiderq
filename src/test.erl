-module(test).
-export([run/4]).

worker_loop(_SpiderQ, 0, _MaxDelayMs) ->
    ok;
worker_loop(SpiderQ, ReqsCount, MaxDelayMs) ->
    CurrentDelayMs = random:uniform(MaxDelayMs),
    {lent, Id, _Data} =
        espiderq:req(SpiderQ, {lend, CurrentDelayMs + 1000}),
    ok = timer:sleep(CurrentDelayMs),
    repaid = 
        espiderq:req(SpiderQ, {repay, Id, case random:uniform(2) of 
                                              1 -> penalty;
                                              2 -> reward 
                                          end}),
    worker_loop(SpiderQ, ReqsCount - 1, MaxDelayMs).

spawn_loop(_SpiderQ, 0, _WorkerReqsCount, _MaxDelayMs) ->
    ok;
spawn_loop(SpiderQ, WorkersCount, WorkerReqsCount, MaxDelayMs) ->
    spawn_link(fun() -> ok = worker_loop(SpiderQ, WorkerReqsCount, MaxDelayMs) end),
    spawn_loop(SpiderQ, WorkersCount - 1, WorkerReqsCount, MaxDelayMs).

run(ConnectArgs, WorkersCount, WorkerReqsCount, MaxDelayMs) ->
    {ok, SpiderQ} = espiderq:start_link(ConnectArgs),
    process_flag( trap_exit, true ),
    ok = spawn_loop(SpiderQ, WorkersCount, WorkerReqsCount, MaxDelayMs),
    {ExecutionMs, ok} = timer:tc(fun() -> wait_done(WorkersCount) end),
    process_flag( trap_exit, false ),
    {ok, 
     {total_ms, ExecutionMs},
     {reqs, (WorkersCount * WorkerReqsCount)},
     {rps, (WorkersCount * WorkerReqsCount) / ExecutionMs}}.

wait_done(0) ->
    ok;
wait_done(WorkersCount) ->
    receive
        { 'EXIT', _Pid, normal } ->
            wait_done(WorkersCount - 1);
        Msg ->
            error({unexpected_msg_received, Msg})
    end.
