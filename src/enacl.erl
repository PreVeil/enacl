-module(enacl).

%% Public key crypto
-export([
	box_keypair/0,
	box/4,
	box_open/4,
	box_nonce_size/0,
	box_public_key_bytes/0,
	box_secret_key_bytes/0
]).

%% Secret key crypto
-export([
	secretbox/3,
	secretbox_open/3,
	secretbox_nonce_size/0,
	secretbox_key_size/0
]).

-export([
	hash/1,
	verify_16/2,
	verify_32/2
]).

%% Low level helper functions
%% -----------------

hash(Bin) -> enacl_nif:crypto_hash(Bin).
verify_16(X, Y) -> enacl_nif:crypto_verify_16(X, Y).
verify_32(X, Y) -> enacl_nif:crypto_verify_32(X, Y).

%% Public Key Crypto
%% ---------------------
box_keypair() ->
	enacl_nif:crypto_box_keypair().

box(Msg, Nonce, PK, SK) ->
    enacl_nif:crypto_box([p_zerobytes(), Msg], Nonce, PK, SK).
    
box_open(CipherText, Nonce, PK, SK) ->
    case enacl_nif:crypto_box_open([p_box_zerobytes(), CipherText], Nonce, PK, SK) of
        {error, Err} -> {error, Err};
        Bin when is_binary(Bin) -> {ok, Bin}
    end.

box_nonce_size() ->
	enacl_nif:crypto_box_NONCEBYTES().

box_public_key_bytes() ->
	enacl_nif:crypto_box_PUBLICKEYBYTES().
	
box_secret_key_bytes() ->
	enacl_nif:crypto_box_SECRETKEYBYTES().

secretbox(Msg, Nonce, Key) ->
    enacl_nif:crypto_secretbox([s_zerobytes(), Msg], Nonce, Key).
    
secretbox_open(CipherText, Nonce, Key) ->
    case enacl_nif:crypto_secretbox_open([s_box_zerobytes(), CipherText], Nonce, Key) of
        {error, Err} -> {error, Err};
        Bin when is_binary(Bin) -> {ok, Bin}
    end.

secretbox_nonce_size() ->
    enacl_nif:crypto_secretbox_NONCEBYTES().
    
secretbox_key_size() ->
    enacl_nif:crypto_secretbox_KEYBYTES().

%% Helpers
p_zerobytes() ->
	binary:copy(<<0>>, enacl_nif:crypto_box_ZEROBYTES()).
	
p_box_zerobytes() ->
	binary:copy(<<0>>, enacl_nif:crypto_box_BOXZEROBYTES()).

s_zerobytes() ->
	binary:copy(<<0>>, enacl_nif:crypto_secretbox_ZEROBYTES()).
	
s_box_zerobytes() ->
	binary:copy(<<0>>, enacl_nif:crypto_secretbox_BOXZEROBYTES()).
