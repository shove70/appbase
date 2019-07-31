module appbase.utils.utility;

import std.file;
import std.path;
import std.string;
import std.conv;
import std.datetime;
import std.array;
import std.uuid;
import std.random;
import std.digest.md;
import std.regex;
import std.algorithm;
import std.traits : Unqual;

string getExePath()
{
    return dirName(thisExePath);
}

string getExeName()
{
    return baseName(thisExePath);
}

string genUuid()
{
    Xorshift192 gen;
    gen.seed(unpredictableSeed);
    auto uuid = randomUUID(gen);
    return uuid.toString.replace("-", "").toUpper();
}

string MD5(scope const(void[])[] src...)
{
    auto md5 = new MD5Digest();
    ubyte[] hash = md5.digest(src);

    return toHexString(hash).toUpper();
}

ubyte[] strToByte_hex(string input)
{
    if (input == string.init)
    {
        return null;
    }

    Appender!(ubyte[]) app;

    for (size_t i; i < input.length; i += 2)
    {
        app.put(input[i .. i + 2].to!ubyte(16));
    }

    return app.data;
}

string byteToStr_hex(T = ubyte)(T[] buffer)
{
    if (buffer.length == 0)
    {
        return string.init;
    }

    Appender!string app;

    foreach (b; buffer)
    {
        app.put(rightJustify(b.to!string(16).toUpper(), 2, '0'));
    }

    return app.data;
}

bool isIPAddress(string ip)
{
    auto re = regex(`^(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9])\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[0-9])$`);
    return !match(ip, re).empty();
}

long ipToLong(string ip)
{
    auto part = split(ip, ".");

    if (part.length != 4)
    {
        return 0;
    }

    long r = as!long(part[3], 0);

    for (int i = 2; i >= 0; i--)
    {
        r += as!long(part[i], 0) << 8 * (3 - i);
    }

    return r;
}

string ipFromLong(long ipInt)
{
    string[4] part;

    for (int i = 3; i >= 0; i--)
    {
        part[i] = to!string(ipInt % 256);
        ipInt /= 256;
    }

    return mergeString(
        part[0].to!string, ".",
        part[1].to!string, ".",
        part[2].to!string, ".",
        part[3].to!string
    );
}

string mergeString(Params...)(Params params)
{
    Appender!string ret;

    foreach(str; params)
    {
        ret.put(str);
    }

    return ret.data;
}

T as(T = int)(string src, T defaultValue)
{
    try
    {
        return to!T(src);
    }
    catch (Exception e)
    {
        return defaultValue;
    }
}

string floatAsString(T = double)(T value) if (is(Unqual!T == double) || is(Unqual!T == float) || is(Unqual!T == real))
{
    long l = cast(long)value;
    T f = value - l;

    return to!string(l) ~ ((f > 0) ? f.to!string[1 .. $] : "");
}

string dateTimeToString(DateTime dt)    // 2017-12-01 00:01:01
{
    return dt.date().toISOExtString() ~ " " ~ dt.timeOfDay().toISOExtString();
}

DateTime dateTimeFromString(string dt, DateTime defaultValue)
{
    if (dt.length > 10 && dt[10] == ' ') dt = dt.replace(" ", "T");
    try
    {
        return DateTime.fromISOExtString(dt);
    }
    catch (Exception e)
    {
        return defaultValue;
    }
}

SysTime sysTimeFromString(string dt, SysTime defaultValue)
{
    dt = strip(dt);

    if ((dt.length > 10) && (dt[10] == 32))
    {
        dt = dt.replace("\x20", "T");
    }

    try
    {
        return SysTime.fromISOExtString(dt);
    }
    catch (Exception e)
    {
        return defaultValue;
    }
}

DateTime now()
{
    return cast(DateTime)Clock.currTime;
}

private const long TICK_BASE = 1460004240;

long currTimeTick()
{
    return Clock.currTime().toUnixTime() - TICK_BASE;
}

SysTime currTimeFromTick(long tick)
{
    return SysTime.fromUnixTime(tick + TICK_BASE);
}

bool inArray(T)(in T[] _array, in T v)
{
    return _array.any!(x => x == v);
}

bool inArray(T)(in T[] _array, in T[] _sub_array)
{
    foreach (v; _sub_array)
    {
        if (!inArray!T(_array, v))
        {
            return false;
        }
    }

    return true;
}

bool inArray(T)(in T[][] _array, in T[] _sub_array)
{
    foreach (v; _array)
    {
        if (v == _sub_array)
        {
            return true;
        }
    }

    return false;
}

bool hasCross(T)(in T[] _array, in T[] arr)
{
    foreach (v; arr)
    {
        if (inArray!T(_array, v))
        {
            return true;
        }
    }

    return false;
}

T maxInArray(T)(in T[] _array)
{
    assert(_array.length > 0);

    T v = T.min;
    foreach (x; _array)
    {
        if (x > v)
        {
            v = x;
        }
    }

    return v;
}

T minInArray(T)(in T[] _array)
{
    assert(_array.length > 0);

    T v = T.max;
    foreach (x; _array)
    {
        if (x < v)
        {
            v = x;
        }
    }

    return v;
}

long pos(T)(in T[] _array, T _value)
{
    foreach (k, v; _array)
    {
        if (v == _value)
        {
            return cast(long)k;
        }
    }

    return -1;
}

T[][] combinationsRecursive(T)(in T[] data, size_t partLength)
{
    if (partLength > data.length)
    {
        return null;
    }

    T[][] result;

    if (partLength == 1)
    {
        data.each!(a => result ~= [ a ]);

        return result;
    }

    T[] _data = data.dup;

    void recursive(ref T[][] result, in T[] t, size_t n, size_t m, T[] b, size_t M)
    {
        for (size_t i = n; i >= m; i--)
        {
            b[m - 1] = cast(T)(i - 1);

            if (m > 1)
            {
                recursive(result, t, cast(T)(i - 1), cast(T)(m - 1), b, M);
            }
            else
            {
                T[] temp = new T[M];

                for (size_t j = 0; j < b.length; j++)
                {
                    temp[j] = t[b[j]];
                }

                result = temp ~ result;
            }
        }
    }

    T[] temp = new T[partLength];
    recursive(result, _data, _data.length, partLength, temp, partLength);

    return result;
}

T_Value[T_Key] dupAssociativeArray(T_Value, T_Key)(T_Value[T_Key] srcArray)
{
    T_Value[T_Key] ret = srcArray.dup;

    foreach (k, ref v; ret)
    {
        v = srcArray[k].dup;
    }

    return ret;
}

T[][] dupArrayArray(T)(T[][] srcArray)
{
    T[][] ret = srcArray.dup;

    foreach (k, ref v; ret)
    {
        v = srcArray[k].dup;
    }

    return ret;
}

T[] dupClassArray(T)(T[] classArray)
{
    T[] ret = classArray.dup;

    foreach (k, ref v; ret)
    {
        v = new T(classArray[k]);
    }

    return ret;
}


__gshared InsecureRandomGenerator rnd;

struct InsecureRandomGenerator
{
    private static Mt19937 generator;

    static this()
    {
        generator.seed(unpredictableSeed);
    }

    T next(T = uint)(T min = T.min, T max = T.max) if (is(Unqual!T == uint) || is(Unqual!T == int) || is(Unqual!T == ubyte) || is(Unqual!T == byte) || is(Unqual!T == ulong) || is(Unqual!T == long)  || is(Unqual!T == ushort) || is(Unqual!T == short) || is(Unqual!T == size_t))
    {
        return uniform!("[]", T, T, typeof(generator))(min, max, generator);
    }
}
