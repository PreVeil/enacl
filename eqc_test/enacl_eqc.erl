-module(enacl_eqc).
-include_lib("eqc/include/eqc.hrl").
-compile(export_all).

nonce_good() ->
    Sz = enacl:box_nonce_size(),
    binary(Sz).
    
nonce_bad() ->
    Sz = enacl:box_nonce_size(),
    oneof([return(a), nat(), ?SUCHTHAT(B, binary(), byte_size(B) /= Sz)]).

nonce_valid(N) when is_binary(N) ->
    Sz = enacl:box_nonce_size(),
    byte_size(N) == Sz;
nonce_valid(_) -> false.

nonce() ->
    fault(nonce_bad(), nonce_good()).

keypair_good() ->
    {ok, PK, SK} = enacl:box_keypair(),
    {PK, SK}.

keypair_bad() ->
    ?LET(X, elements([pk, sk]),
      begin
        {ok, PK, SK} = enacl:box_keypair(),
        case X of
            pk ->
              PKBytes = enacl:box_public_key_bytes(),
              {oneof([return(a), nat(), ?SUCHTHAT(B, binary(), byte_size(B) /= PKBytes)]), SK};
            sk ->
              SKBytes = enacl:box_secret_key_bytes(),
              {PK, oneof([return(a), nat(), ?SUCHTHAT(B, binary(), byte_size(B) /= SKBytes)])}
        end
      end).

keypair() ->
    fault(keypair_bad(), keypair_good()).

%% CRYPTO BOX
%% ---------------------------


keypair_valid(PK, SK) when is_binary(PK), is_binary(SK) ->
    PKBytes = enacl:box_public_key_bytes(),
    SKBytes = enacl:box_secret_key_bytes(),
    byte_size(PK) == PKBytes andalso byte_size(SK) == SKBytes;
keypair_valid(_PK, _SK) -> false.

prop_box_keypair() ->
    ?FORALL(_X, return(dummy),
        ok_box_keypair(enacl:box_keypair())).
       
ok_box_keypair({ok, _PK, _SK}) -> true;
ok_box_keypair(_) -> false.

box(Msg, Nonce , PK, SK) ->
    try
        enacl:box(Msg, Nonce, PK, SK)
    catch
        error:badarg -> badarg
    end.

box_open(CphText, Nonce, PK, SK) ->
    try
        enacl:box_open(CphText, Nonce, PK, SK)
    catch
         error:badarg -> badarg
    end.

failure(badarg) -> true;
failure(_) -> false.

prop_box_correct() ->
    ?FORALL({Msg, Nonce, {PK1, SK1}, {PK2, SK2}},
            {binary(),
             fault_rate(1, 40, nonce()),
             fault_rate(1, 40, keypair()),
             fault_rate(1, 40, keypair())},
        begin
            case nonce_valid(Nonce) andalso keypair_valid(PK1, SK1) andalso keypair_valid(PK2, SK2) of
                true ->
                    CipherText = enacl:box(Msg, Nonce, PK2, SK1),
                    {ok, DecodedMsg} = enacl:box_open(CipherText, Nonce, PK1, SK2),
                    equals(Msg, DecodedMsg);
                false ->
                    case box(Msg, Nonce, PK2, SK1) of
                        badarg -> true;
                        Res -> failure(box_open(Res, Nonce, PK1, SK2))
                    end
            end
        end).

prop_box_failure_integrity() ->
    ?FORALL({Msg, Nonce, {PK1, SK1}, {PK2, SK2}},
            {binary(),
             fault_rate(1, 40, nonce()),
             fault_rate(1, 40, keypair()),
             fault_rate(1, 40, keypair())},
        begin
            case nonce_valid(Nonce)
                 andalso keypair_valid(PK1, SK1)
                 andalso keypair_valid(PK2, SK2) of
                true ->
                    CipherText = enacl:box(Msg, Nonce, PK2, SK1),
                    Err = enacl:box_open([<<"x">>, CipherText], Nonce, PK1, SK2),
                    equals(Err, {error, failed_verification});
                false ->
                    case box(Msg, Nonce, PK2, SK1) of
                      badarg -> true;
                      Res ->
                        failure(box_open(Res, Nonce, PK1, SK2))
                    end
            end
        end).

%% CRYPTO SECRET BOX
%% -------------------------------

secret_key_good() ->
	Sz = enacl:secretbox_key_size(),
	binary(Sz).
	
secret_key_bad() ->
	oneof([return(a),
	       nat(),
	       ?SUCHTHAT(B, binary(), byte_size(B) /= enacl:secretbox_key_size())]).
	
secret_key() ->
	fault(secret_key_bad(), secret_key_good()).

secret_key_valid(SK) when is_binary(SK) ->
	Sz = enacl:secretbox_key_size(),
	byte_size(SK) == Sz;
secret_key_valid(_SK) -> false.

secretbox(Msg, Nonce, Key) ->
  try
    enacl:secretbox(Msg, Nonce, Key)
  catch
    error:badarg -> badarg
  end.
  
secretbox_open(Msg, Nonce, Key) ->
  try
    enacl:secretbox_open(Msg, Nonce, Key)
  catch
    error:badarg -> badarg
  end.

prop_secretbox_correct() ->
    ?FORALL({Msg, Nonce, Key},
            {binary(), 
             fault_rate(1, 40, nonce()),
             fault_rate(1, 40, secret_key())},
      begin
        case nonce_valid(Nonce) andalso secret_key_valid(Key) of
          true ->
             CipherText = enacl:secretbox(Msg, Nonce, Key),
             {ok, DecodedMsg} = enacl:secretbox_open(CipherText, Nonce, Key),
             equals(Msg, DecodedMsg);
          false ->
             case secretbox(Msg, Nonce, Key) of
               badarg -> true;
               Res ->
                 failure(secretbox_open(Res, Nonce, Key))
             end
        end
      end).
      
prop_secretbox_failure_integrity() ->
    ?FORALL({Msg, Nonce, Key}, {binary(), nonce(), secret_key()},
      begin
        CipherText = enacl:secretbox(Msg, Nonce, Key),
        Err = enacl:secretbox_open([<<"x">>, CipherText], Nonce, Key),
        equals(Err, {error, failed_verification})
      end).

%% HASHING
%% ---------------------------
diff_pair(Sz) ->
    ?SUCHTHAT({X, Y}, {binary(Sz), binary(Sz)},
        X /= Y).

data_bad() ->
  oneof([return(a), nat()]).

data_good(Sz) -> binary(Sz).

data(Sz) ->
  fault(data_bad(), data_good(Sz)).

data_valid(B) when is_binary(B) -> true;
data_valid(_B) -> false.

prop_crypto_hash_eq() ->
    ?FORALL(Sz, oneof([1, 128, 1024, 1024*4]),
    ?FORALL(X, data(Sz),
        case data_valid(X) of
          true -> equals(enacl:hash(X), enacl:hash(X));
          false ->
            try
              enacl:hash(X),
              false
            catch
              error:badarg -> true
            end
        end
    )).
    
prop_crypto_hash_neq() ->
    ?FORALL(Sz, oneof([1, 128, 1024, 1024*4]),
    ?FORALL({X, Y}, diff_pair(Sz),
        enacl:hash(X) /= enacl:hash(Y)
    )).

%% STRING COMPARISON
%% -------------------------

verify_pair_bad(Sz) ->
  ?LET(X, elements([fst, snd]),
    case X of
      fst ->
        {?SUCHTHAT(B, binary(), byte_size(B) /= Sz), binary(Sz)};
      snd ->
        {binary(Sz), ?SUCHTHAT(B, binary(), byte_size(B) /= Sz)}
    end).

verify_pair_good(Sz) ->
  oneof([
    ?LET(Bin, binary(Sz), {Bin, Bin}),
    ?SUCHTHAT({X, Y}, {binary(Sz), binary(Sz)}, X /= Y)]).
    
verify_pair(Sz) ->
  fault(verify_pair_bad(Sz), verify_pair_good(Sz)).

verify_pair_valid(Sz, X, Y) ->
    byte_size(X) == Sz andalso byte_size(Y) == Sz.

prop_verify_16() ->
    ?FORALL({X, Y}, verify_pair(16),
      case verify_pair_valid(16, X, Y) of
          true ->
              equals(X == Y, enacl:verify_16(X, Y));
          false ->
              try
                 enacl:verify_16(X, Y),
                 false
              catch
                  error:badarg -> true
              end
      end).
      
prop_verify_32() ->
    ?FORALL({X, Y}, verify_pair(32),
      case verify_pair_valid(32, X, Y) of
          true ->
              equals(X == Y, enacl:verify_32(X, Y));
          false ->
              try
                 enacl:verify_32(X, Y),
                 false
              catch
                  error:badarg -> true
              end
      end).