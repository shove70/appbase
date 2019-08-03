module appbase.configuration;

import std.traits;
import std.array;
import std.conv;
import std.file;
import std.exception;
import std.string;
import std.format;
import std.variant;
import std.algorithm.searching : canFind;
import std.algorithm.iteration : each;

alias config = Configuration.getInstance;

class ConfigurationNotLoadException : Exception
{
    mixin basicExceptionCtors;
}

class ConfigurationFileNotExistsException : Exception
{
    mixin basicExceptionCtors;
}

class ConfigurationFormatException : Exception
{
    mixin basicExceptionCtors;
}

class ConfigurationNotSettingException : Exception
{
    mixin basicExceptionCtors;
}

class ConfigurationNotReifiedException : Exception
{
    mixin basicExceptionCtors;
}

package class ConfigurationValue
{
    ConfigurationValue opAssign(string value)
    {
        _value = value;
        _reified = false;
        _arraying = false;

        return this;
    }

    @property void reified_value(T)(T value)
    {
        _reified_value = value;
        _reified = true;
    }

    @property T reified_value(T)()
    {
        enforce!ConfigurationNotReifiedException(_reified, format("ConfigurationValue %s is not reified.", _value));
        return _reified_value.get!T;
    }

    @property T[] array(T)()
    {
        if (!_arraying)
        {
            synchronized(ConfigurationValue.classinfo)
            {
                if (!_arraying)
                {
                    string[] t = _value.split(',');
                    t.each!((ref a) => (a = (strip(a))));
                    static if (isSomeString!T)
                        _array = t;
                    else static if (is(T == bool))
                    {
                        bool[] t2 = new bool[t.length];
                        t.each!((i, a) => (t2[i] = [ "true", "t", "yes", "y", "1", "-1" ].canFind(a.toLowwer)));
                        _array = t2;
                    }
                    else
                    {
                        T[] t2 = new T[t.length];
                        t.each!((i, a) => (t2[i] = cast(T)a));
                        _array = t2;
                    }

                    _arraying = true;
                }
            }
        }

        return _array.get!(T[]);
    }

    @property void default_value(T)(T value)
    {
        _default_value = value;
        _defaulted = true;
    }

    @property T default_value(T)()
    {
        if (_defaulted)
            return _default_value.get!T;
        else
            return T.init;
    }

private:

    string _value;
    Variant _reified_value;
    Variant _array;
    Variant _default_value;

    bool _reified, _arraying, _defaulted; 
}

package class ConfigurationItem(string ConfigurationType = "file")
{
    this()
    {
        _value = new ConfigurationValue();
    }

    @property value(string name)
    {
        auto v =  _map.get(name, null);
        enforce!ConfigurationNotSettingException(v, format("%s is not in %s.", name, ConfigurationType));
        return v;
    }

    @property value()
    {
        return _value._value;
    }

    @property void reified_value(T)(T value)
    {
        _value.reified_value = value;
    }

    @property reified_value(T)()
    {
        return _value.reified_value!T;
    }

    @property T[] array(T)()
    {
        return _value.array!T;
    }

    @property void default_value(T)(T value)
    {
        _value.default_value = value;
    }

    @property T default_value(T)()
    {
        return _value.default_value!T;
    }

    auto opCast(T)()
    {
        static if (is(T == bool))
            return as!bool;
        else static if (isSomeString!T)
            return cast(T)(value());
        else static if (isNumeric!(T))
            return as!T;
        else
            static assert(0, "Not support type.");
    }

    auto as(T)() if (isNumeric!(T))
    {
        if (_value._value.length == 0)
            return _value.default_value!T;
        else
            return to!T(_value._value);
    }

    auto as(T: bool)()
    {
        if ([ "true", "t", "yes", "y", "1", "-1" ].canFind(_value._value.toLower))
            return true;
        
        if ([ "false", "f", "no", "n", "0" ].canFind(_value._value.toLower))
            return false;

        return _value.default_value!bool;
    }

    auto as(T: string)()
    {
        if (_value._value.length == 0)
            return _value.default_value!string;
        else
            return _value._value;
    }

    auto opDispatch(string s)()
    {
        return value(s);
    }

package:

    ConfigurationValue _value;
    ConfigurationItem!(ConfigurationType)[string] _map;
}

final class Configuration
{
    @property value(string name)
    {
        enforce!ConfigurationNotLoadException(_loaded, "Configuration is not be load().");
        return _value.value(name);
    }

    auto opDispatch(string s)()
    {
        enforce!ConfigurationNotLoadException(_loaded, "Configuration is not be load().");
        return _value.opDispatch!(s)();
    }

    @property __gshared static Configuration getInstance()
    {
        if (_instance is null)
        {
            synchronized(Configuration.classinfo)
            {
                if (_instance is null)
                {
                    _instance = new Configuration();
                }
            }
        }

        return _instance;
    }

    void load(string filename, string section = string.init)
    {
        enforce!ConfigurationFileNotExistsException(exists(filename), format("Configuration file %s is not exists.", filename));
        _value = new ConfigurationItem!("file")();

        import std.stdio : File;
        auto f = File(filename, "r");
        if (!f.isOpen()) return;
        scope(exit) f.close();

        string _section = string.init;
        int line = 1;

        while (!f.eof())
        {
            scope(exit) line += 1;
            string str = f.readln();
            str = strip(str);

            if (str.length == 0) continue;
            if (str[0] == '#' || str[0] == ';') continue;

            auto len = cast(int)str.length - 1;
            if (str[0] == '[' && str[len] == ']')
            {
                _section = str[1..len].strip;
                continue;
            }

            if (_section != section)
                continue;

            auto site = str.indexOf("=");
            enforce!ConfigurationFormatException((site > 0), format("The format is error in file %s, in line %d", filename, line));
            string key = str[0..site].strip;
            fill(split(key, '.'), str[site + 1..$].strip);
        }

        _loaded = true;
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
                tvalue = new ConfigurationItem!("file")();
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

    bool _loaded;
    ConfigurationItem!("file") _value;
    __gshared Configuration _instance = null;
}
