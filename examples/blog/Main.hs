{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Data.ByteString.Char8 as S8 (pack)
import Web.Simple
import Web.Simple.Auth
import Web.Simple.Cache
import Web.REST (restIndex)
import System.Environment
import Network.Wai
import Network.Wai.Middleware.Static
import Network.Wai.Handler.Warp
import Network.Wai.Middleware.MethodOverridePost
import Network.Wai.Middleware.RequestLogger
import System.FilePath

import Blog.Controllers.CommentsController
import Blog.Controllers.PostsController

app runner = do
  env <- getEnvironment
  let adminUser = maybe "admin" S8.pack $ lookup "ADMIN_USERNAME" env
  let adminPassword = maybe "password" S8.pack $ lookup "ADMIN_PASSWORD" env

  let requireAuth = basicAuth "Simple Blog Admin" adminUser adminPassword

  runner $ methodOverridePost $
    mkRouter $ do
      routePattern "admin" $ requireAuth $ do
        routeName "posts" $ do
          routePattern ":post_id/comments" $ commentsAdminController
          routeAll $ postsAdminController
        routeTop $ redirectTo "/admin/posts/"
      routeName "posts" $ do
        routePattern ":post_id/comments" $ commentsController
        routeAll $ postsController
      routeTop $ restIndex $ postsController
      routeAll $ staticPolicy (addBase "static") $ const $ return notFound

main :: IO ()
main = do
  env <- getEnvironment
  let port = maybe 3000 read $ lookup "PORT" env
  putStrLn $ "Starting server on port " ++ (show port)
  app (run port . logStdout)

