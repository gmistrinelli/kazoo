-module(kz_cache_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").

cache_test_() ->
    {'timeout'
    ,10
    ,{'spawn'
     ,{'setup'
      ,fun init/0
      ,fun cleanup/1
      ,fun(_CachePid) ->
               [{"key exists", fun wait_for_key_local_existing/0}
               ,{"key appears", fun wait_for_key_local_mid_stream/0}
               ,{"key timeout", fun wait_for_key_local_timeout/0}
               ,{"load test", fun load/0}
               ]
       end
      }
     }
    }.

init() ->
    {'ok', CachePid} = kz_cache:start_link(?MODULE),
    CachePid.

cleanup(CachePid) ->
    kz_cache:stop_local(CachePid).

wait_for_key_local_existing() ->
    Timeout = rand:uniform(1000)+1000,
    Key = kz_binary:rand_hex(5),
    Value = kz_binary:rand_hex(5),

    kz_cache:store_local(?MODULE, Key, Value),

    _WriterPid = spawn_monitor(fun() -> writer_job(Key, Value, Timeout) end),

    ?assertEqual({'ok', Value}, kz_cache:wait_for_key_local(?MODULE, Key, Timeout)).

wait_for_key_local_mid_stream() ->
    Timeout = rand:uniform(1000)+1000,
    Key = kz_binary:rand_hex(5),
    Value = kz_binary:rand_hex(5),

    _WriterPid = spawn_monitor(fun() -> writer_job(Key, Value, Timeout) end),

    ?assertEqual({'ok', Value}, kz_cache:wait_for_key_local(?MODULE, Key, Timeout)).

wait_for_key_local_timeout() ->
    Timeout = 1000,
    Key = kz_binary:rand_hex(5),

    ?assertEqual({'error', 'timeout'}, kz_cache:wait_for_key_local(?MODULE, Key, Timeout)).

writer_job(Key, Value, Timeout) ->
    timer:sleep(Timeout div 2),
    kz_cache:store_local(?MODULE, Key, Value).

load() ->
    Fun = fun() ->
              Key =  kz_binary:rand_hex(5),
              Value =  kz_binary:rand_hex(5),
              Timeout = 0,
              writer_job(Key, Value, Timeout)
          end,
    Spawns = [spawn_monitor(Fun) || _ <- lists:seq(1,1)],
    ?debugFmt("~nSpawns: ~p~n", [Spawns]),
    wait_for(Spawns).

wait_for([]) ->
    'ok';
wait_for([{Pid, Ref} | Spawns]) ->
    ?debugFmt("Expecting Pid=~p, Ref=~p~n", [Pid, Ref]),
    receive
        {'DOWN', Ref, process, Pid, normal} -> wait_for(Spawns);
        Reason ->
            ?debugFmt("Got reason: ~p, exiting~n", [Reason]),
            exit(Reason)
    end.
