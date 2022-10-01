-module(utils).
-include("include/defines.hrl").
-compile(nowarn_export_all).
-compile(export_all).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%--------------Data Parallel Utils-----------%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% splits the list into chunks of equal length
make_chunks(Len,List) ->
   make_chunks(List,[],0,Len).
make_chunks([],Acc,_,_) -> Acc;
make_chunks([Hd|Tl],Acc,Start,Max) when Start==Max ->
   make_chunks(Tl,[[Hd] | Acc],1,Max);
make_chunks([Hd|Tl],[Hd0 | Tl0],Start,Max) ->
   make_chunks(Tl,[[Hd | Hd0] | Tl0],Start+1,Max);
make_chunks([Hd|Tl],[],Start,Max) ->
   make_chunks(Tl,[[Hd]],Start+1,Max).

% creates a list of all the integers from 0 to (2^Exp - 1)
create_list(Exp) ->
   Len = round(math:pow(2,Exp)),
   lists:seq(0, Len-1).

% combines a list of lists into a single list
combine([]) -> [];
combine([X|Xs]) -> lists:append(X, combine(Xs)).

% cleans up the output of the google mapreduce
clean_up(Result) ->
   Tuples = dict:to_list(Result),
   [ X||{_,[X]}<-Tuples].

% the mapper matching atoms with words in each file
match_to_file(Regex) ->
   fun (_, File, Fun) ->
      {ok, [Atoms]} = file:consult(File),
      lists:foreach(fun (Atom) ->
         case Regex == Atom of
           true -> Fun(Atom, File);
           false -> false
         end
      end, Atoms)
   end.

% the reducer removing duplicate elements
get_unique(Atom, Files, Fun) ->
   Unique_Files = sets:to_list(sets:from_list(Files)),
   lists:foreach(fun (File) -> Fun(Atom, File) end, Unique_Files).

% indexing all files inside the directory
index_file_list(Dirpath) ->
   {ok, Files} = file:list_dir(Dirpath),
   Filepaths = [filename:join(Dirpath, File) || File <- Files ],
   Indices = lists:seq(1, length(Files)),
   lists:zip(Indices, Filepaths).

% getting the path containing the test/log directory
get_dirpath() ->
   {_,Currpath} = file:get_cwd(),
   filename:dirname(Currpath).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%--------Stream Parallel Utils-------------%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% convert to and from tuple form
format(Input) ->
   {input,Input}.
extract({input,Input}) ->
   Input.
apply(Fun) ->
   fun({input,Input}) ->
      {input,Fun(Input)}
   end.

% send messages to a process, eos is an
% atom representing the end of the stream
stop(Pid) ->
   Pid ! {msg,eos}.
send(Input,Pid) ->
   Msg = format(Input),
   Pid ! Msg.
send_results(Results,Pid) ->
   Pid ! {results,Results}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%-------------Testing Utils----------------%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% tests the given function N times and puts the
% results in a list of time measurements
test_loop(0,_Fun, Times) ->
   Times;
test_loop(N,Fun,Times) ->
   {Time,_} = timer:tc(Fun),
   test_loop(N-1,Fun,[Time|Times]).

% takes the mean time of a list of time measurements
% after removing the worst and best ones
mean(List) ->
   Clean_List = tl(lists:reverse(tl(lists:sort(List)))),
   lists:foldl(fun(X,Sum)-> X+Sum end, 0, Clean_List) / length(Clean_List).

% takes the median of a list of time measurements
median(List) ->
   lists:nth(round((length(List) / 2)), lists:sort(List)).

% takes the speedup. that is, the improvement in speed
% between the sequential version and the parallel version
speedup(Time_Seq,Time_Par) ->
   Time_Seq/Time_Par.

% sets the number of schedulers online
set_schedulers(N) ->
   catch(erlang:system_flag(schedulers_online,N)).

% return the number of schedulers schedulers_online
get_schedulers() ->
   erlang:system_info(schedulers_online).

% prints a summary
report(Name, Time, Mean, Median) ->
   io:format("~p version times: ~p~n",[Name,Time]),
   io:format("~p version times mean is", [Name]),
   io:format(" ~pms, whilst times median is ~pms~n",[Mean/?MSEC,Median/?MSEC]).

print_time() ->
   {{Year,Month,Day},{Hour,Min,Sec}} = erlang:localtime(),
   io_lib:format("~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B",
      [Year, Month, Day, Hour, Min, Sec]).
