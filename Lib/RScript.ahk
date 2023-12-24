buildRScriptContent(Path,output_filename="",out="") {
    SplitPath % Path, , Path2, , Name
    RScriptFilePath:=strreplace(Path2,"\","\\")
        , RScriptFolder:=strreplace(Path2,"\","/")
    OutputType_Print:=""
    for _, output_type in out.sel {
        OutputType_Print.="sprintf('" output_type "')`n"
    }
    Str=
        (LTRIM
            cat("\014") ## clear console
            remove (list=ls()) ## clear environment variables
            getwd()
            if (getwd() != "%RScriptFolder%")
            {
            setwd("%RScriptFilePath%")
            getwd()
            }
            getwd()
            sprintf('Chosen Output formats:')
            %OutputType_Print%
            version
        )
    if out.settings.bForceFixPNGFiles {
        Str2=
            (LTrim
                files <- list.files(pattern="*.PNG",recursive = TRUE)
                files2 <- list.files(pattern="*.png",recursive = TRUE)
                filesF <- c(files,files2)
                lapply(filesF,ImgFix  <- function(Path="")
                {
                png_image  <- magick::image_read(Path)
                jpeg_image <- magick::image_convert(png_image,"JPEG")
                png_image  <- magick::image_convert(jpeg_image,"PNG")
                magick::image_write(png_image,Path)
                sprintf( "Fixed Path '`%s'", Path)
                })
            )
        Str.="`n" Str2
        bFixPNGs:=true
    }
    else {
        bFixPNGs:=false
    }
    Name:=(output_filename!=""?output_filename:"index")
        , FormatOptions:=""
    for _, Class in out.Outputformats { 
        Class.FilenameMod:=" (" Class.package ")"
        Class.Filename:=Name
    }
    for _,Class in out.Outputformats {
        format:=Class.AssembledFormatString
        if Instr(format,"pdf") {
            continue
        }
        Str3:=LTrim(Class.renderingpackage)
        if (Trim(Str3)!="") {
            if (format="") {
                Str3:=Strreplace(Str3,"%format%","NULL")
            } else {
                Str3:=Strreplace(Str3,"%format%",format)
            }
        } else {
            Str3:=format
        }
        Str3:=Strreplace(Str3,"%Name%",Name Class.FilenameMod)
        Str.="`n`n" Str3
        FormatOptions.= A_Tab strreplace(format,"`n",A_Tab "`n") "`n`n"
    }
    ;; pdf handling
    for _, Class in out.Outputformats { 
        format:=Class.AssembledFormatString
        if !Instr(format,"pdf") {

            continue
        }
        Str3:="`n`n`n`n" LTrim(Class.renderingpackage)
        if (RegexMatch(Str3,"\S+")) {
            if (format="") {
                Str3:=Strreplace(Str3,"%format%","NULL")
            } else {
                Str3:=Strreplace(Str3,"%format%",format)
            }
        } else {
            Str3:=format
        }
        Str3:=Strreplace(Str3,"%Name%",Name Class.FilenameMod)
        Str2=
            (LTrim
                files <- list.files(pattern="*.PNG",recursive = TRUE)
                files2 <- list.files(pattern="*.png",recursive = TRUE)
                filesF <- c(files,files2)
                lapply(filesF,ImgFix  <- function(Path="")
                {
                png_image  <- magick::image_read(Path)
                jpeg_image <- magick::image_convert(png_image,"JPEG")
                png_image  <- magick::image_convert(jpeg_image,"PNG")
                magick::image_write(png_image,Path)
                sprintf( "Fixed Path '`%s'", Path)
                })




                rmarkdown::render(`"index.rmd`",%format%,`"%Name%"`)`n
            )
        if bFixPNGs {
            ;Str2:="`n" Str3 "`n"
        }
        Str.="`n`n" Str3
        FormatOptions.= A_Tab strreplace(format,"`n",A_Tab "`n") "`n`n"
    }
    Str2=
        (LTRIM

            sprintf("'build.R' successfully finished running.")
        )
    Str.=Str2
    ;OD(,Str,FormatOptions)
    return [Str,FormatOptions,RScriptFolder]

}
rscript_check() {
    static rscript_on_path:=false
    static out:=""
    if !rscript_on_path {
        GetStdStreams_WithInput("where rscript.exe",,out)
        out:=strreplace(out,"`n")
        if !FileExist(out) {
            rscript_on_path:=false
        } else {
            rscript_on_path:=true
        }
    }
    return [rscript_on_path,out]
}
runRScript(Path,script_contents,Outputformats,RScript_Path:="") {
    SplitPath % Path,, OutDir
    writeFile(OutDir "\build.R",script_contents,"UTF-8-RAW",,true)
    if !FileExist(RScript_Path) {
        RScript_Path:=rscript_check().2
        if !FileExist(RScript_Path) {
            MsgBox 0x10,% script.name " - " A_ThisFunc "()", % "Error encountered`; the Path provided for the RScript-Utility ('" RScript_Path "') does not point to a valid file.`nAdditionally, Rscript is not part of the PATH variable, thus 'where rscript' fails as well. The manuscript cannot be compiled to output formats.`nLocate RScript or manually execute the rscript to proceeed."
            return ["FILENOTFOUND:" RScript_Path,"where rscript",""]
        }
    }
    CMD:=Quote_ObsidianHTML(RScript_Path) A_Space Quote_ObsidianHTML(strreplace(OutDir "\build.R","\","\")) ;; works with valid codefile (manually ensured no utf-corruption) from cmd, all three work for paths not containing umlaute with FileAppend
    if DEBUG {
        CLipboard:=CMD "`n" OutDir "`n`n`n`n" Quote_ObsidianHTML(InOut)
    }
    GetStdStreams_WithInput(CMD, OutDir, InOut:="`n")
    if DEBUG {
        Clipboard:=InOut
    }
    if !validateRExecution(InOut,Outputformats) {
        MsgBox 0x10,% script.name " - " A_ThisFunc "()", % "Error encountered`; the 'build.R'-script did not run to succession.`n`nFor more information, see the generated 'Executionlog.txt'-file, and execute the 'build.R'-script via console or RStudio.`n`nThe script will continue to cleanup its working directories now.",4
    }
    return [InOut,CMD,OutDir]
}

validateRExecution(String,Formats) {
    OutputDebug % String
    Expected:=Finished:=0
    Expected:=Formats.Count()
    Finished+=st_count(String,"Output created:")
    if InStr(String,"'build.R' successfully finished running.") {
        return true
    } else {
        if (Expected>Finished) {
            return false
        } else {
            return true
        }
    }
}
