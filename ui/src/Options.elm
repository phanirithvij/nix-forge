module Options.Create exposing (..)

import Dict
import Http
import Options.Config exposing (..)
import Options.Config.App exposing (..)
import Options.Config.Package exposing (..)
import Options.Create.Model exposing (..)
import Options.Create.Update exposing (..)
import Options.Create.View exposing (..)
import Options.Option exposing (..)
import Options.Output exposing (..)


initCreate : () -> ( ModelCreate, Cmd UpdateCreate )
initCreate _ =
    ( { options = []
      , packagesFilter = Dict.empty
      , appsFilter = Dict.empty
      , recipeDirPackages = ""
      , recipeDirApps = ""
      , selectedOption = Nothing
      , searchString = ""
      , category = OutputCategory_Packages
      , packagesSelectedFilter = Nothing
      , appsSelectedFilter = Nothing
      , showInstructions = False
      , error = Nothing
      }
    , Cmd.batch [ getOptions, getConfig ]
    )


getOptions : Cmd UpdateCreate
getOptions =
    Http.get
        { url = "options.json"
        , expect = Http.expectJson UpdateCreate_GetOptions optionsDecoder
        }


getConfig : Cmd UpdateCreate
getConfig =
    Http.get
        { url = "forge-config.json"
        , expect = Http.expectJson UpdateCreate_GetConfig configDecoder
        }
