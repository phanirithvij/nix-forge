module Main.Helpers.Nix exposing (..)


type alias NixUrl =
    String


showNixUrl : NixUrl -> String
showNixUrl url =
    if String.startsWith "github:" url then
        "https://github.com/" ++ String.dropLeft 7 url

    else if String.startsWith "path:" url then
        "#"

    else
        url


showGithubRepoSlug : NixUrl -> String
showGithubRepoSlug url =
    String.dropLeft 7 url
