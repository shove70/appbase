module appbase.utils.log;

import std.path : buildPath;
import std.conv : to;
import std.experimental.logger.core : LogLevel;
import std.experimental.logger.filelogger : FileLogger, CreateFolder;
import std.datetime;

import appbase.utils.utility;

alias logger = Logger;

/// file logger.
struct Logger
{
    private __gshared Date today;
    private __gshared FileLogger fl;
 
    /// write log to file.
    static void write(string file = __FILE__, size_t line = __LINE__,
        string funcName = __FUNCTION__,
        string prettyFuncName = __PRETTY_FUNCTION__,
        string moduleName = __MODULE__,
        Args...)(Args args)
    {
        if (args.length == 0)
        {
            return;
        }

        DateTime dt = now;
        if ((dt.date != today) || (fl is null))
        {
            synchronized
            {
                if ((dt.date != today) || (fl is null))
                {
                    if (fl !is null)
                    {
                        fl.file.flush();
                        fl.file.close();
                    }

                    today = dt.date;
                    const auto filename = buildPath(getExePath(), "log", dt.year.to!string, dt.date.toISOString() ~ ".log");
                    fl = new FileLogger(filename, LogLevel.all, CreateFolder.yes);
                }
            }
        }

        fl.log!(line, file, funcName, prettyFuncName, moduleName)(getExeName, ", ", args);
    }
}
