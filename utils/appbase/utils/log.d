module appbase.utils.log;

import std.file;
import std.path;
import std.conv;
import std.string;
import std.experimental.logger.core;
import std.experimental.logger.filelogger;

import appbase.utils.utility;

struct logger
{
    static string logFile;

    static void write(string file = __FILE__, size_t line = __LINE__)(string msg)
    {
        if (msg == string.init)
        {
            return;
        }

        string path = buildPath(getExePath(), "log", now.year.to!string);

        if (!std.file.exists(path))
        {
            std.file.mkdirRecurse(path);
        }

        string filename = buildPath(path, now.date.toISOString() ~ ".log");

        if ((logFile == string.init) || (logFile != filename))
        {
            synchronized
            {
                if ((logFile == string.init) || (logFile != filename))
                {
                    logFile   = filename;
                    sharedLog = new FileLogger(logFile);
                }
            }
        }

        log(getExeName ~ "/" ~ file ~ ":" ~ line.to!string ~ ": " ~ msg);
    }
}
