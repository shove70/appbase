module appbase.utils.log;

import core.sync.mutex;
import std.path : buildPath;
import std.conv : to;
import std.experimental.logger.core : LogLevel;
import std.experimental.logger.filelogger : FileLogger, CreateFolder;
import std.datetime;
import std.stdio : writeln;

import appbase.utils.utility;

/// file logger.
struct Logger
{
    private __gshared Date today;
    private __gshared FileLogger fl;
 
    private __gshared Mutex _mutex;

    private static this()
    {
        _mutex = new Mutex();
    }

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
            synchronized (_mutex)
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

        fl.log!(line, file, funcName, prettyFuncName, moduleName)(getExeName, ": ", args);
    }

    static void flush(const bool closeFile = false)
    {
        synchronized (_mutex)
        {
            fl.file.flush();

            if (closeFile)
            {
                fl.file.close();
                fl = null;
            }
        }
    }
}
alias logger = Logger;


/// classification file logger.
struct LoggerEx
{
    private __gshared Date today;
    private __gshared FileLogger[ubyte] fl;

    private __gshared Mutex _mutex;
 
    private static this()
    {
        _mutex = new Mutex();
    }

    /// write log to file.
    static void write(string file = __FILE__, size_t line = __LINE__,
        string funcName = __FUNCTION__,
        string prettyFuncName = __PRETTY_FUNCTION__,
        string moduleName = __MODULE__,
        Args...)(ubyte classification, Args args)
    {
        if (args.length == 0)
        {
            return;
        }

        DateTime dt = now;
        if ((dt.date != today) || (classification !in fl) || (fl[classification] is null))
        {
            synchronized (_mutex)
            {
                if ((dt.date != today) || (classification !in fl) || (fl[classification] is null))
                {
                    if ((classification in fl) && (fl[classification] !is null))
                    {
                        fl[classification].file.flush();
                        fl[classification].file.close();
                    }

                    today = dt.date;
                    const auto filename = buildPath(getExePath(), "log", dt.year.to!string, dt.date.toISOString(), classification.to!string ~ ".log");
                    fl[classification] = new FileLogger(filename, LogLevel.all, CreateFolder.yes);
                }
            }
        }

        fl[classification].log!(line, file, funcName, prettyFuncName, moduleName)(getExeName, ": ", args);
    }

    static void flush(const bool closeFile = false)
    {
        synchronized (_mutex)
        {
            foreach (ref f; fl)
            {
                f.file.flush();

                if (closeFile)
                {
                    f.file.close();
                    f = null;
                }
            }
        }
    }
}
alias loggerEx = LoggerEx;


void writelnEx(string file = __FILE__, size_t line = __LINE__,
        string funcName = __FUNCTION__,
        string prettyFuncName = __PRETTY_FUNCTION__,
        string moduleName = __MODULE__,
        Args...)(Args args)
{
    writeln(appbase.utils.now, " ", file, ":", line, ":", funcName, ": ", args);
}
