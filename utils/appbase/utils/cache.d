module appbase.utils.cache;

import std.conv;
import std.datetime;
import std.variant;

__gshared private CacheValue[string] _cacheContainer;

private class CacheValue
{
    DateTime time;
    int expireMinutes;
    Variant value;

    this(Variant value, int expireMinutes)
    {
        time = cast(DateTime)Clock.currTime();
        this.expireMinutes = expireMinutes;
        this.value = value;
    }
}

class Cache
{
    static void set(T)(string key, T value, int expireMinutes = 30)
    {
        _cacheContainer[key] = new CacheValue(Variant(value), expireMinutes);
    }

    static T get(T)(string key, T defaultValue)
    {
        CacheValue item;

        if (key !in _cacheContainer)
        {
            return defaultValue;
        }

        synchronized (Cache.classinfo)
        {
            if (key !in _cacheContainer)
            {
                return defaultValue;
            }

            item = _cacheContainer.get(key, null);

            if (item is null)
            {
                return defaultValue;
            }

            DateTime now = cast(DateTime)Clock.currTime();
            if ((now - item.time).total!"minutes" > item.expireMinutes)
            {
                _cacheContainer.remove(key);

                return defaultValue;
            }
        }

        if (!item.value.convertsTo!T)
        {
            return defaultValue;
        }

        return item.value.get!T;
    }

    static void remove(string key)
	{
		if (key in _cacheContainer)
        {
            synchronized (Cache.classinfo)
            {
                if (key in _cacheContainer)
                {
                    _cacheContainer.remove(key);
                }
            }
		}
	}
}
