module appbase.mysql.dao;

import database.mysql;

alias DataRow = string[string];
alias DataRows = DataRow[];

DataRow queryOneRow(bool Prepared = true, Params...)(Connection conn, string cmd, Params params)
{
    DataRows rows = query!(Prepared)(conn, cmd, params);

    if (rows.length == 0)
    {
        return null;
    }

    return rows[0];
}

DataRows query(bool Prepared = true, Params...)(Connection conn, string cmd, Params params)
{
    DataRows rows;
    
    static if (Prepared)
        conn.execute(cmd, params, (MySQLRow row) {
            rows ~= row.toAA();
        });
    else
        conn.executeNoPrepare(cmd, params, (MySQLRow row) {
            rows ~= row.toAA();
        });

    return rows;
}

// Return affected, no lastInsertId.
// Get the lastInsertId: use conn.lastInsertId() please.
ulong exec(bool Prepared = true, Params...)(Connection conn, string cmd, Params params)
{
    static if (Prepared)
    {
        auto upd = conn.prepare(cmd);
        conn.execute(upd, params);
    }
    else
    {
        conn.executeNoPrepare(cmd, params);
    }

    return conn.affected();
}

DataRows selectDataRows(DataRows rows, string key, string value)
{
    int start = -1;
    int end = -1;

    int i = 0;
    while (i < rows.length)
    {
        if (rows[i][key] == value)
        {
            start = i;
            break;
        }

        i++;
    }

    if (start < 0)
    {
        return rows[0 .. 0];
    }

    i = start + 1;
    while (i < rows.length)
    {
        if (rows[i][key] != value)
        {
            end = i;
            break;
        }

        i++;
    }

    if (end < 0)
    {
        end = cast(int)rows.length;
    }

    return rows[start .. end];
}

DataRows selectDataRows(DataRows rows, int rowsInPage, int pageno)
{
    if (rows.length == 0) return rows;
    if ((pageno - 1) * rowsInPage > cast(int)rows.length - 1) return rows[0 .. 0];
    return rows[(pageno - 1) * rowsInPage .. (pageno * rowsInPage >= rows.length) ? rows.length : pageno * rowsInPage];
}
