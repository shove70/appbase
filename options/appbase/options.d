module appbase.options;

import std.array;
import std.conv;
import std.exception;
import std.string;
import std.format;
import std.datetime;

import database.mysql;

import appbase.configuration;
import appbase.mysql;

alias options = Options.getInstance;

class OptionsNotLoadException : Exception
{
    mixin basicExceptionCtors;
}

final class Options
{
    @property value(string name)
    {
        enforce!OptionsNotLoadException(_loaded, "Options is not be load().");

        refresh();
        return _value.value(name);
    }

    auto opDispatch(string s)()
    {
        enforce!OptionsNotLoadException(_loaded, "Options is not be load().");

        refresh();
        return _value.opDispatch!(s)();
    }

    @property __gshared static Options getInstance()
    {
        if (_instance is null)
        {
            synchronized(Options.classinfo)
            {
                if (_instance is null)
                {
                    _instance = new Options();
                }
            }
        }

        return _instance;
    }

    void load(string tableName, int expire = 0)
    {
        Connection conn = getConnection();
        DataRows rows = query(conn, "select * from " ~ tableName ~ " order by id;");
        releaseConnection(conn);

        _value = new ConfigurationItem!("database")();

        foreach (row; rows)
        {
            string key = strip(row["key"]);

            if (key.length == 0) continue;
            if (key[0] == '#' || key[0] == ';') continue;

            fill(split(key, '.'), row["value"].strip);
        }

        _loaded = true;

        _tableName = tableName;
        _expire = expire;
        _loadTime = cast(DateTime)Clock.currTime();
    }

private:

    void fill(string[] key, string value)
    {
        auto cvalue = _value;
        foreach (ref k; key)
        {
            if (k.length == 0) continue;

            auto tvalue = cvalue._map.get(k, null);

            if (tvalue is null)
            {
                tvalue = new ConfigurationItem!("database")();
                cvalue._map[k] = tvalue;
            }

            cvalue = tvalue;
        }

        if (cvalue is _value)
        {
            return;
        }

        cvalue._value = value;
    }

    void refresh()
    {
        if (_expire <= 0)
            return;

        DateTime now = cast(DateTime)Clock.currTime();
        if ((now - _loadTime).total!"minutes" > _expire)
        {
            synchronized (Options.classinfo)
            {
                if ((now - _loadTime).total!"minutes" > _expire)
                {
                    load(_tableName, _expire);
                }
            }
        }
    }

    bool _loaded;
    ConfigurationItem!("database") _value;
    __gshared Options _instance = null;

    string _tableName;
    int _expire;
    DateTime _loadTime;
}
