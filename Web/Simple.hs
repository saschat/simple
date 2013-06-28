{- |


/Simple/ is based on WAI - an standard interface for communicating between web
servers (like warp) and web applications. You can use /Simple/ completely
independently (and of course, use any WAI server to run it). Alternatively, you
can embed existing existing WAI applications inside an app built with /Simple/,
and embed an app built with simple in another WAI app.

All the components in /Simple/ are designed to be small and simple
enough to understand, replaceable, and work as well independantly as they do
together.

-}
module Web.Simple (
    module Web.Simple.Responses
  , module Web.Simple.Controller
  -- * Overview
  -- $Overview

  -- * Tutorial
  -- $Tutorial

  -- ** Routing
  -- $Routing

  -- ** Responses
  -- $Responses

  -- ** Controllers
  -- $Controllers

  -- ** Migrations
  -- $Migrations
  ) where

import Web.Simple.Responses
import Web.Simple.Controller

{- $Overview
 #overview#

WAI applications are functions of type 'Network.Wai.Application' - given a
client 'Network.Wai.Request' they return a 'Network.Wai.Response' to return to
the client (i.e. an HTTP status code, headers, body etc\'). A /Simple/
application is composed of a set of 'Routeable's -- a typeclass similar to an
'Network.Wai.Application' except it returns a 'Maybe' 'Network.Wai.Response'.

The simplest instance of 'Routeable' is a 'Network.Wai.Application' itself.
This is a 'Routeable' that always succeeds. A 'Controller' is an 'Application',
but it internalizes the 'Network.Wai.Request' argument in a
'Control.Monad.Trans.ReaderT' and provides some convenience methods for
accessing properties of the request (e.g. parsing form data). More
interestingly, 'Route's can decide whether to respond to the 'Network.Wai.Request' dynamically, based on
the contents of the 'Network.Wai.Request' or any external input (e.g. time of
day, a database query etc\'). For example, 'routeHost' falls-through to it\'s
second argument (another 'Routeable') if the \"Host\" header in the client\'s
'Network.Wai.Request' matches the first argument:

@
  routeHost \"hackage.haskell.org\" myHackageApp
@

There are other 'Route's for matching based on the request path, the HTTP
method, and it\'s easy to write other 'Route's. 'Route' is also an instance of
'Monad' and 'Data.Monoid.Monoid' so they can be chained together to route
requests in a single application to different controllers. If the first 'Route'
fails, the next is tried until there are no more 'Route's. Thus, a /Simple/ app
might look something like this:

@
  mkRouter $ do
    routeTop $ do
      ... handle home page ...
    routeName \"posts\" $ do
      routeMethod GET $
        ... get all posts ...
      routeMethod POST $
        ... create new post ...
@

where 'mkRouter' generates an 'Network.Wai.Application' from a 'Routeable'
returning a 404 (not found) response if all routes fail.

It\'s convenient to specialize sets of these 'Route's for some common patters.
This package includes the "Web.Frank" module which provide an API to create
applications similar to the Sinatra framework for Ruby, and the "Web.REST"
module to create RESTful applications similar to Ruby on Rails. The example
above could be rewritten using "Web.Frank" as such:

@
  mkRouter $ do
    get \"/\" $ do
      ... display home page ...
    get \"/posts\" $ do
      ... get all posts ...
    post \"/posts\" $ do
      ... create new post ...
@

This package is broken down into the following modules:

@
  Web
  |-- "Web.Simple" - Re-exports most common modules
  |   |-- "Web.Simple.Router" - defines 'Routeable' and base 'Route's
  |   |-- "Web.Simple.Controller" - Monad for writing controller bodies
  |   |-- "Web.Simple.Responses" - Common HTTP responses
  |   |-- "Web.Simple.Auth" - 'Routeable's for authentication
  |   |-- "Web.Simple.Cache" - in memory and filesystem cache utilities
  |   +-- "Web.Simple.Migrations"
  |-- "Web.Frank" - Sinatra style 'Route's
  +-- "Web.REST" - Monad for creating RESTful controllers
@

-}

{- $Tutorial
#tutorial#

/Simple/ comes with a utility called \smpl\ which automates some common tasks
like creating a new application, running migrations and launching a development
server. To create a new /Simple/ app in a directory called \"example_app\", run:

@
  $ smpl create example_app
@

This will create a directory called \"example_app\" with an empty subdirectory
called \"migrate\" (more on that later) and a single Haskell source file,
\"Main.hs\":

@
\{\-\# LANGUAGE OverloadedStrings #\-\}

module Main where

import Web.Simple

app runner = runner $ mkRouter $ okHtml \"Hello World\"
@

The `app` function is the entry point to your application. The argument is a
function that knows how to run a `Network.Wai.Application` -- for example,
warp's run method. `mkRouter` transforms a `Routeable` into an
`Network.Wai.Application`. The boilerplate is just a `Response` with the body
\"Hello World\" (and content-type \"text/html\"). To run a development server
on port 3000:

@
  $ cd example_app
  $ smpl
@

Pointing your browser to <http://localhost:3000> should display
\"Hello World\"!
-}

{- $Routing
#routing#

An app that does the same thing for every request is not very useful (well, it
might be, but if it is, even /Simple/ is not simple enough for you). We want to
build applications that do perform different actions based on properties of the
client\'s request - e.g., the path requests, GET or POST requests, the \"Host\"
header, etc\'. With /Simple/ we can accomplish this with 'Route's.
'Route's are an instance of the 'Routeable' typeclass, and encapsulate a
function from a 'Request' to a 'Maybe' 'Response'. If the request matches the
'Route', it will fallthrough (usually to an underlying 'Routeable' like a
'Controller' or another 'Route'). 'Route' is also an instance of 'Monad' and
'Data.Monoid.Monoid' so you can easily chain and nest 'Route's.

For example, let\'s extend the example using the 'Monad' syntax:

@
app runner = runner $ mkRouter $ do
                routeTop $ do
                  routeHost \"localhost\" $ okHtml \"Hello, localhost!\"
                  routeHost \"test.lvh.me\" $ okHtml \"Hello, test.lvh.me!\"
                routeName \"advice\" $ okHtml \"Be excellent to each other!\"
@

Now, the app will respond differently depending on whether the client is
requesting the host name \"localhost\" or \"test.lvh.me\", or if the requested
path is \"\/advice\" rather than \"\/\". Take it for a spin in the browser (make
sure `smpl` is still running):

  * <http://localhost:3000>

  * <http://test.lvh.me:3000>

  * <http://localhost:3000/advice>

In this example, 'routeTop' matches if the 'Network.Wai.Request's
'Network.Wai.pathInfo' is empty, which means the requested path is \"\/\" (as
in this case), or the rest of the path has been consumed by previous 'Route's.
'routeName' matches if the next component in the path (specifically the 'head'
of 'Network.Wai.pathInfo') matches the argument (and if so, removes it). Check
out "Web.Simple.Router" for more complete documentation of these and other
'Route's.

For many apps it will be convenient to use even higher level routing APIs. The
modules "Web.Frank" and "Web.Sinatra" provide Sinatra-like and RESTful APIs,
respectively. Both modules are implement purely in terms of 'Route's and you
can easily implement your own patterns as well.

-}

{- $Responses
#responses#

You may have notice that our examples all included lines such as

@
  okHtml \"Some response body\"
@

'okHtml' is one of a few helper functions to construct HTTP responses.
Specifically, it return a 'Network.Wai.Response' with status 200 (OK),
conetent-type \"text\/html\" and the argument as the response body. The module
"Web.Simple.Responses" contains other response helpers, such as 'notFound',
'redirectTo', 'serverError', etc\'.

-}

{- $Controllers
#controllers#

-}

{- $Migrations
#migrations#
-}
