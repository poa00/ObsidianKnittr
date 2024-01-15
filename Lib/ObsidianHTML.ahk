﻿ObsidianHtml(manuscript_path:="",config_path:="",bUseConvert:=true,bUseOwnOHTMLFork:=false,bVerbose:=false,OutputDir="",WorkDir:="",WorkDir_OwnFork:="",ScopeRestrictorObject:="") {

    if (WorkDir="") {
        WorkDir:= A_Desktop "\ObsidianHTMLOutput"
    }
    if (WorkDir_OwnFork="") {
        WorkDir_OwnFork:= A_Desktop "\ObsidianHTMLOutput"

    }

    ;; get ObsidianHTML_Path
    if (bUseOwnOHTMLFork) {
        obsidianhtml_path:=WorkDir_OwnFork "\obsidianhtml"
    } else {
        if obsidianhtml_check().1 {
            obsidianhtml_path:=obsidianhtml_check().2
            obsidianhtml_path:=Trim(obsidianhtml_path)
        } else {
            MsgBox 0x2010, script.name " - ObsidianHTML not found ", "The CLI-Utility ObsidianHTML could not be found via 'where obsidianhtml'.`nAs this script is not functional without it, it will exit now."
            return false
        }
    }

    ;; ensure the Working Directory exists before running OHTML
    if (!FileExist(OutputDir)) {
        FileCreateDir % OutputDir
    }

    ;; if no manuscript is provided, we must assume the config to contain it and use convert
    bUseConvert:=(manuscript_path=""?true:false)

    ;; Validate config file.
    if (!FileExist(config_path)) {
        MsgBox 0x2010, script.name " - provided Config file does not exist ", % "The config-file provided to 'obsidianhtml convert - i <config_file> does not exist. Returning early."
        return false
    } else {
        FileRead config_contents, % config_path
        if !Instr(config_contents,"obsidian_entrypoint_path_str: '") && bUseConvert {
            MsgBox 0x2010
                , % script.name " - config-field 'obsidian_entrypoint_path_str' not found "
                , % "The config-file provided does not contain the setting 'obsidian_entrypoint_path_str', which is required for running the 'convert'-option. Please check the code. The script will reload now."
            reload
        }
    }

    command2_getversion := "obsidianhtml version"
    if bUseConvert {
        command2:= "obsidianhtml convert -i " Quote_ObsidianHTML(Trim(config_path))
    } else {
        if (manuscript_path="") {
            MsgBox 0x2010, script.name " > " A_ThisFunc, No manuscript_path was provided to the run-verb execution. The script will reload. `n`nPlease provide a valid note-path or choose to convert.
            reload
        }
        command2:= "obsidianhtml run -f " Quote_ObsidianHTML(Trim(manuscript_path)) " -i " Quote_ObsidianHTML(Trim(config_path))
    }
    ;; Check Verbosity
    if bVerbose {
        command2.= " -v "
    }
    ;; validate used version of OHTML
    if bUseOwnOHTMLFork {
        if python_check().1 {
            GetStdStreams_WithInput("python --version",,out)
            GetStdStreams_WithInput("python -m " command2_getversion,WorkDir_OwnFork,ohtmlversion_modded)
        }
        if (script.config.config.ConfirmOHTMLCustomBuild && !bAutoSubmitOTGUI) {
            MsgBox 0x2034,% "Is the correct build version used?", % "Has the correct build version been used?`n" ohtmlversion_modded "`n`nCMD:`n" command2, 1 ;; TODO: add config option to skip this, and add option to potentially also or never skip this when debugging.
            IfMsgBox Yes, {

            } Else IfMsgBox No, {
                if (FileExist(ScopeRestrictorObject.Path) && !ScopeRestrictorObject.IsVaultRoot) {
                    FileRemoveDir % ScopeRestrictorObject.Path
                }
                reload
            }
        }
    }

    if bUseOwnOHTMLFork {
        GetStdStreams_WithInput("python -m " command2,WorkDir_OwnFork,data_modded:="`n")
        ohtmlversion_out:=strreplace(ohtmlversion_modded,"`n commit:"," (commit:")
        ohtmlversion_out:=strreplace(ohtmlversion_out,"`n") ")"
        data_out:=data_modded
        WorkDir_out:=WorkDir_OwnFork
    } else {
        GetStdStreams_WithInput(command2_getversion,WorkDir,ohtmlversion)
        GetStdStreams_WithInput(command2,WorkDir,data:="`n")
        ohtmlversion_out:=ohtmlversion
        data_out:=data
        WorkDir_out:=WorkDir
    }
    OutputDebug % "`n`n" command2 "`n`n"
    OutputDebug % "`n`n" WorkDir "`n`n"
    OutputDebug % "`n`n" WorkDir_OwnFork "`n`n"
    OutputDebug % "`n`n" data_out "`n`n"

    if (data!="") {
        OHTML_Output:=getObsidianHTML_WD(data)
        ObsidianHTMLCopyDir:=getObsidianHTML_CopyDir(data)
    }
    if (data_modded!="") {
        OHTML_Output:=getObsidianHTML_WD(data_modded)
        ObsidianHTMLCopyDir:=getObsidianHTML_CopyDir(data_modded)
    }
    return {"CMD":command2
            ,"WorkDir":WorkDir_out
            ,"stdOut":data_out
            ,"obsidianhtml_version":ohtmlversion_out
            ,"obsidianhtml_path":obsidianhtml_path
            ,"OutputPath":OHTML_Output
            ,"ObsidianHTMLCopyDir":ObsidianHTMLCopyDir}
}

getObsidianHTML_WD(String) {
    NeedleTxt:="
        (LTRIM
            from (?<Path>.*obshtml_.*\/)
            md: (?<Path>.*obshtml_.*(\/|\\)md)
            md: (?<Path>.*\md)
            \> COMPILING HTML FROM MARKDOWN CODE \((?<Path>.*\\md)\\index\.md\)
            m)\> COMPILING HTML FROM MARKDOWN CODE \((?<Path>.*)\)
            m)\> COMPILING HTML FROM MARKDOWN CODE \((?<Path>.+)\)+$
            \> COMPILING HTML FROM MARKDOWN CODE \((?<Path>.+)\)+
            md: (?<Path>.*\\md)
        )"
    needles:=strsplit(NeedleTxt,"`n")
    for _, needle in needles {
        Regexmatch(String,needle,v)
        if FileExist(vPath) {
            return vPath
        }
    }
    return String
}
getObsidianHTML_CopyDir(String) {
    OutputDebug % String
    NeedleTxt:="
        (LTrim
            COPYING VAULT (?<d_>.*) TO (?<TempDir>.*)$
            m)resolved:\s*(?<TempDir>.*)$
            m)resolved \+ posix:\s*(?<TempDir>.*)$
        )"
    needles:=strsplit(NeedleTxt,"`n")
    for _, needle in needles {
        matches:=Regexmatch(String, needle, v)
        if (vTempDir!="") {
            vTempDir:=strsplit(vTempDir,"`n",,2).1
            return vTempDir
        }
    }
    return
}
createTemporaryObsidianHTML_Config(manuscriptpath, obsidianhtml_configfile,Convert) {
    if !FileExist(obsidianhtml_configfile) || !InStr(obsidianhtml_configfile,A_ScriptDir) { ;; create a template in this folder
        template:="
            (LTRIM
                # Input and output path of markdown files
                # This can be an absolute or a relative path (relative to the working directory when calling obsidianhtml)
                # Use full path or relative path, but don't use ~/
                # md_folder_path_str:  'output/md'
                # Number of links a note can be removed from the entrypoint note
                # -1 for no max depth
                # 0 means only the entrypoint note is processed
                # 1 means only direct children are processed (and the entrypoint of course)
                # and so forth. NOTE: DOES NOT APPLY TO INCLUSIONS!
                #obsidian_entrypoint_path_str: '`%obsidian_entrypoint_path_str`%'
                # module_data_folder: 'output/mod'
                max_note_depth: 15
                # preserve_inline_tags: False
                copy_vault_to_tempdir: True
                exclude_glob:
                %A_Space%%A_Space%- "".git""
                %A_Space%%A_Space%- "".obsidian""
                %A_Space%%A_Space%- "".trash""
                %A_Space%%A_Space%- "".vscode""
                %A_Space%%A_Space%- "".DS_Store""
                %A_Space%%A_Space%- ""002 templates""
                %A_Space%%A_Space%- "".Rproj.user""
                %A_Space%%A_Space%- ""renv""
                exclude_subfolders:
                %A_Space%%A_Space%- "".git""
                %A_Space%%A_Space%- "".obsidian""
                %A_Space%%A_Space%- "".trash""
                %A_Space%%A_Space%- "".vscode""
                %A_Space%%A_Space%- "".DS_Store""
                %A_Space%%A_Space%- ""002 templates""
                %A_Space%%A_Space%- "".Rproj.user""
                %A_Space%%A_Space%- ""renv""














                toggles:
                # When true, Obsidianhtml will not add three spaces at the end of every line
                strict_line_breaks: True
                # compile_html: False
                features:
                %A_Space%%A_Space%embedded_note_titles:
                %A_Space%%A_Space%%A_Space%%A_Space%enabled: False
                # big css/js files to download + data to download 
                # and read in that scales with the size of the site.
                %A_Space%%A_Space%graph:
                %A_Space%%A_Space%%A_Space%%A_Space%enabled: False
                %A_Space%%A_Space%search:
                %A_Space%%A_Space%%A_Space%%A_Space%enabled: False

                # big css/js files to download.
                %A_Space%%A_Space%mermaid_diagrams:
                %A_Space%%A_Space%%A_Space%%A_Space%enabled: False
                %A_Space%%A_Space%math_latex:
                %A_Space%%A_Space%%A_Space%%A_Space%enabled: False

                # small, css based features.
                %A_Space%%A_Space%code_highlight:
                %A_Space%%A_Space%%A_Space%%A_Space%enabled: False
                %A_Space%%A_Space%callouts:
                %A_Space%%A_Space%%A_Space%%A_Space%enabled: False
            )"
        template:=fixYAMLSyntax(template)
        OutputDebug % template
        writeFile_ObsidianHTML(script.configfolder "\OHTMLconfig_template.yaml",template,,,true)
        obsidianhtml_configfile:=script.configfolder "\OHTMLconfig_template.yaml"
    }
    FileRead configfile_contents, % obsidianhtml_configfile
    if (Convert) {
        configfile_contents:=StrReplace(configfile_contents,"#obsidian_entrypoint_path_str: '%obsidian_entrypoint_path_str%'","obsidian_entrypoint_path_str: '" manuscriptpath "'")
    }
    SplitPath % manuscriptpath

    writeFile_ObsidianHTML(configfile_path:=A_ScriptDir "\OHTMLconfig_temp.yaml",configfile_contents,,,true)
    return [(FileExist(configfile_path)?configfile_path:false),configfile_contents]
}

readObsidianHTML_Config(configpath) {
    if !FileExist(configpath)
        return "E01: No config found"
    FileRead txt, % configpath
    if (txt="")
        return "E02: Empty config file"
    conf:=[]
    confstr:=""
    for _, Line in strsplit(txt,"`n") {
        Line:=trim(Line)
        if !Instr(Line, ":") && Instr(Line, "# ") {
            continue
        }
        if RegExMatch(Line, "(?<Key>.*):(?<Value>.*)", v) {
            conf[vKey]:=vValue
                , confstr.= vKey "=" vValue "`n"
        }
    }
    if (confstr="") {
        return "E03: Config file contains no valid YAML config found in provided file."
    }
    return [conf,confstr]
}
fixYAMLSyntax(template) {
    out:=""
    bInTogglesSection:=false
    if (!RegexmatchAll(template,"im)(?<Val>^toggles:)",v)) { ;; no toggles section, so nothing to indent
        return template
    }
    Lines:=strsplit(template,"`n")
    for _, Line in Lines {
        if !(bInTogglesSection || RegexMatch(Line,"mi)^toggles")) {
            out.=Line "`n"
            continue
        } else {
            if (!bInTogglesSection && RegexMatch(Line,"mi)^toggles")) {
                out.=Line "`n"
                    , bInTogglesSection:=true
                Continue
            }
        }
        if (bInTogglesSection) {
            FirstChar:=SubStr(LTRIM(Line),1,1)
            if (FirstChar="#") { ;; a comment
                out.=Line "`n"
                continue
            } else { ;; an actual toggle
                if (SubStr(Line,1,2)!=" ") {
                    Line:=A_Space A_Space Line
                        , out.=Line "`n"
                } else {
                    out.=Line "`n"
                }
            }
        }
    }
    out:=strreplace(out,"%A_Space%",A_Space)
    OutputDebug % out
    return out
}

updateObsidianHTMLToLastRelease() {
    RunWait % A_Comspec " /k echo y | pip uninstall obsidianhtml", ,
    RunWait % A_Comspec " /k echo y | pip install obsidianhtml", ,
    MsgBox,, % script.name, % "Successfully updated to last Release."
    return
}
updateObsidianHTMLToMaster() {
    RunWait % A_Comspec " /k echo y | pip uninstall obsidianhtml", ,
    RunWait % A_Comspec " /k echo y | pip install git+https://github.com/obsidian-html/obsidian-html.git", ,
    MsgBox,, % script.name, % "Successfully updated to Master."
    return
}
obsidianhtml_check() {
    static obsidianhtml_on_path:=false
    static out:=""
    if !obsidianhtml_on_path {
        GetStdStreams_WithInput("where obsidianhtml",,out)
        out:=strreplace(out,"`n")
        if !FileExist(out) {
            obsidianhtml_on_path:=false
        } else {
            obsidianhtml_on_path:=true
        }
    }
    return [obsidianhtml_on_path,out]
}
python_check() {
    static python_on_path:=false
    static out:=""
    if !python_on_path {
        GetStdStreams_WithInput("where python.exe",,out)
        out:=strsplit(out,"`n")
        for _, path in out {
            if !FileExist(path) {
                python_on_path:=false
            } else {
                python_on_path:=true
                out:=path
                break
            }
        }
    }
    return [python_on_path,out]
}
; #region:Quote (4179423054)
; #region:Metadata:
; Snippet: Quote;  (v.1)
; --------------------------------------------------------------
; Author: u/anonymous1184
; Source: https://www.reddit.com/r/AutoHotkey/comments/p2z9co/comment/h8oq1av/?utm_source=share&utm_medium=web2x&context=3
; (11.11.2022)
; --------------------------------------------------------------
; Library: AHK-Rare
; Section: 05 - String/Array/Text
; Dependencies: /
; AHK_Version: v1
; --------------------------------------------------------------
; Keywords: apostrophe
; #endregion:Metadata

; #region:Description:
; Quotes a string
; #endregion:Description

; #region:Example
; Var:="Hello World"
; msgbox, % Quote_ObsidianHTML(Var . " Test")
;
; #endregion:Example

; #region:Code
Quote_ObsidianHTML(String) { ; u/anonymous1184 https://www.reddit.com/r/AutoHotkey/comments/p2z9co/comment/h8oq1av/?utm_source=share&utm_medium=web2x&context=3
    return """" String """"
}
; #endregion:Code

; #endregion:Quote (4179423054)
; #region:writeFile_ObsidianHTML (3352591673)
; #region:Metadata:
; Snippet: writeFile_ObsidianHTML;  (v.1.0)
;  10 April 2023
; --------------------------------------------------------------
; Author: Gewerd Strauss
; License: MIT
; --------------------------------------------------------------
; Library: Personal Library
; Section: 10 - Filesystem
; Dependencies: /
; AHK_Version: v1
; --------------------------------------------------------------
; Keywords: encoding, UTF-8/UTF-8-RAW
; #endregion:Metadata

; #region:Description:
; Small function for writing files to disk in a safe manner when requiring specific file encodings or flags.
; Allows f.e. UTF-8 filewrites
; #endregion:Description

; #region:Example
; Loop, Files, % Folder "\*." script.config.Config.filetype, F
;         {
;             scriptWorkingDir:=renameFile(A_LoopFileFullPath,Arr[A_Index],true,A_Index,TrueNumberOfFiles)
;             writeFile_ObsidianHTML(scriptWorkingDir "\gfa_renamer_log.txt",Files, "UTF-8-RAW","w",true)
;         }
; #endregion:Example

; #region:Code
writeFile_ObsidianHTML(Path,Content,Encoding:="",Flags:=0x2,bSafeOverwrite:=false) {
    if (bSafeOverwrite && FileExist(Path)) {
        FileDelete % Path
    } ;; if we want to ensure nonexistance.
    if (Encoding!="")
    {
        if (fObj:=FileOpen(Path,Flags,Encoding))
        {
            fObj.Write(Content) ;; insert contents
            fObj.Close() ;; close file
        }
        else {
            throw Exception("File could not be opened. Flags: " Flags "`nPath: " Path, -1, Path)
        }
    }
    else
    {
        if (fObj:=FileOpen(Path,Flags))
        {
            fObj.Write(Content) ;; insert contents
            fObj.Close() ;; close file
        }
        else {
            throw Exception("File could not be opened. Flags: " Flags "`nPath: " Path, -1, Path)
        }
    }
    return
}
; #endregion:Code

; #endregion:writeFile_ObsidianHTML (3352591673)
