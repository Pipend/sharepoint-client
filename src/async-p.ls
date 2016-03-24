Promise = require \bluebird

# :: -> p a 
new-promise = (res, rej) ->
    new Promise res, rej

# :: p a -> (a -> p b) -> p b
bind-p = (p, f) -> p.then f

# :: a -> p a
return-p = (a) -> new-promise (res) -> res a

# :: a -> p a
reject-p = (a) -> new-promise (, rej) -> rej a

# :: ((Error, result) -> a) -> p a
from-error-value-callback = (f, self = null) ->
    (...args) ->
        _res = null
        _rej = null
        args = args ++ [(error, result) ->
            return _rej error if !!error
            _res result
        ]
        (res, rej) <- new-promise
        _res := res
        _rej := rej
        try
            f.apply self, args
        catch ex
            rej ex

# ::
to-callback = (p, callback) ->
    p
    .then (result) -> callback null, result
    .catch (err) -> callback err, null

module.exports = {Promise, new-promise, bind-p, return-p, reject-p, from-error-value-callback}