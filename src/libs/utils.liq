# Get the value associated to a variable in the process environment.
# Returns "" if the variable is not set.
# @category System
def getenv(~default="", s) =
  list.assoc(default=default, s, environment())
end

# Split the arguments of an url of the form `arg=bar&arg2=bar2` into
# `[("arg","bar"),("arg2","bar2")]`. The returned strings are decoded (see
# `url.decode`).
# @category String
# @param args Argument string to split.
def url.split_args(args) =
  def f(x) =
    ret = r/=/.split(x)
    arg = url.decode(list.nth(default="",ret,0))
    val = url.decode(list.nth(default="",ret,1))
    (arg,val)
  end
  l = r/&/.split(args)
  list.map(f,l)
end

# Split an url of the form `foo?arg=bar&arg2=bar2` into
# `("foo",[("arg","bar"),("arg2","bar2")])`. The returned strings are decoded
# (see `url.decode`).
# @category String
# @param uri Url to split.
def url.split(uri) =
  ret = r/([^\?]*)\?(.*)/.exec(uri)
  args = ret[2]
  if args != "" then
    (url.decode(ret[1]),url.split_args(ret[2]))
  else
    (url.decode(uri),[])
  end
end

# Memoize the result of a function,
# making sure it is only executed once.
def memoize(fn) =
  cached_result = ref([])
  fun () -> begin
    if !cached_result != [] then
      list.hd(!cached_result)
    else
      result = fn()
      cached_result := [result]
      result
    end
  end
end
