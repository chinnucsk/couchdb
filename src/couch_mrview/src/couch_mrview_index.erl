-module(couch_mrview_util).


-export([db_name/1, index_name/1, signature/1]).
-export([update_seq/1, set_update_seq/2, purge_seq/1]).
-export([open_index/1, close_index/1]).
-export([update_options/1, process_doc/2, purge_index/2, commit/1]).
-export([compact/2, recompact/2, switch_compacted/2]).
-export([reset/1]).


-include_lib("couch_mrview/include/couch_mrview.hrl").


db_name(#mrst{db_name=DbName}) ->
    DbName.


index_name(#mrst{idx_name=IdxName}) ->
    IdxName.


signature(#mrst{sig=Sig}) ->
    Sig.


update_seq(#mrst{update_seq=UpdateSeq}) ->
    UpdateSeq.


set_update_seq(Seq, State) ->
    State#mrst{update_seq=Seq}.


purge_seq(#mrst{purge_seq=PurgeSeq}) ->
    PurgeSeq.


open_index(Db, State) ->
    #mrst{
        db_name=DbName,
        sig=Sig,
        root_dir=RootDir
    } = State,
    case couch_mrview_util:open_index_file(RootDir, DbName, Sig) of
        {ok, Fd} ->
            case (catch couch_file:read_header(Fd)) of
                {ok, {Sig, Header}} ->
                    % Matching view signatures.
                    {ok, couch_mrview_util:init_state(Db, Fd, State, Header)};
                _ ->
                    {ok, couch_mrview_util:reset_file(Db, Fd, State)}
            end;
        Error ->
            catch couch_mrview_util:delete_index_file(RootDir, DbName, Sig)
        end
    end.


close_index(State) ->
    couch_file:close(State#mrst.fd).


purge_index(Db, PurgeSeq, PurgedIdRevs, State) ->
    couch_mrview_updater:purge_index(Db, PurgeSeq, PurgedIdRevs, State).


update_options(#mrst{design_opts=Opts}=State) ->
    Opts1 = case couch_util:get_value(<<"include_design">>, Opts, false) of
        true -> [include_design];
        _ -> []
    end,
    Opts2 = case couch_util:get_value(<<"local_seq">>, Opts, false) of
        true -> [local_seq];
        _ -> []
    end,
    Opts1 ++ Opts2.


start_update(Parent, PartialDest, State) ->
    couch_mrview_updater:start_update(Parent, PartialDest, State).


finish_update(State) ->
    couch_mrview_updater:finish_update(State).


process_doc(Doc, State) ->
    couch_mrview_updater:process_doc(Doc, State).



commit(State) ->
    Header = {State#mrst.sig, couch_mrview_util:make_header(State)},
    couch_file:write_header(State#mrst.fd, Header).


compact(Parent, State, Opts) ->
    couch_mrview_compactor:compact(Parent, State, Opts).


swap_compacted(OldState, NewState) ->
    couch_mrview_compactor:swap(OldState, NewState).


reset_index(State) ->
    couch_mrview_util:reset_index(State).
