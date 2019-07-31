module appbase.utils.expression;

import std.conv;
import std.variant;
import std.uni;
import std.container.dlist;

import appbase.utils.utility;
import appbase.utils.container.stack;

class Expression
{
    double calc(string express)
    {
        Stack!string stackOperators;
        Stack!double stackNumerials;

        Token[] tokens = scanner(express);

        string operator = string.init, topOperator  = string.init;
        double numerial = 0.0, top1Numerial = 0.0, top2Numerial = 0.0;

        for (size_t i = 0; i < tokens.length; i++)
        {
            Token token = tokens[i];

            if (token.type == 2)
            {
                stackNumerials.push(token.value.get!double);

                continue;
            }

            operator = token.value.get!string;

            if (operator == "[")
            {
                stackOperators.push(operator);

                continue;
            }

            if (isCalcOperator(operator))
            {
                if (i >= tokens.length - 1)
                {
                    assert(0, "Syntax error in expression: " ~ express);
                }

                Token nextToken = tokens[i + 1];

                if ((nextToken.type != 2) && (nextToken.value.get!string != "["))
                {
                    assert(0, "Syntax error in expression: " ~ express);
                }

                if ((stackOperators.length == 0) || (!isCalcOperator(stackOperators.back())))
                {
                    stackOperators.push(operator);

                    continue;
                }

                topOperator = stackOperators.back();

                if (getPriority(operator) > getPriority(topOperator))
                {
                    stackOperators.push(operator);

                    continue;
                }

                topOperator  = stackOperators.pop();
                top1Numerial = stackNumerials.pop();
                top2Numerial = stackNumerials.pop();
                numerial = calc(top2Numerial, top1Numerial, topOperator);
                stackNumerials.push(numerial);

                stackOperators.push(operator);

                continue;
            }

            if (operator == "]")
            {
                if ((stackOperators.length == 0) || (!isCalcOperator(stackOperators.back())))
                {
                    assert(0, "Syntax error in expression: " ~ express);
                }

                while (stackOperators.length > 0)
                {
                    topOperator  = stackOperators.pop();
                    top1Numerial = stackNumerials.pop();
                    top2Numerial = stackNumerials.pop();
                    numerial = calc(top2Numerial, top1Numerial, topOperator);
                    stackNumerials.push(numerial);

                    if (stackOperators.length == 0)
                    {
                        assert(0, "Syntax error in expression: " ~ express);
                    }

                    topOperator = stackOperators.back();

                    if (topOperator == "[")
                    {
                        stackOperators.pop();

                        break;
                    }
                }
            }
        }

        while (stackOperators.length > 0)
        {
            topOperator = stackOperators.pop();

            if (!isCalcOperator(topOperator))
            {
                assert(0, "Syntax error in expression: " ~ express);
            }

            top1Numerial = stackNumerials.pop();
            top2Numerial = stackNumerials.pop();
            numerial = calc(top2Numerial, top1Numerial, topOperator);
            stackNumerials.push(numerial);
        }

        numerial = stackNumerials.pop();
        return numerial;
    }

private:

    class Token
    {
        int     type;  // 1: operator, 2: numerical
        Variant value;

        this(int type, string value)
        {
            this.type  = type;
            this.value = Variant(value);
        }

        this(int type, double value)
        {
            this.type  = type;
            this.value = Variant(value);
        }
    }

    Token[] scanner(string express)
    {
        Token[] result;
        string  token = "";

        for (size_t i = 0; i < express.length; i++)
        {
            char ch = express[i];

            if (isWhite(ch))
            {
                continue;
            }

            if (isOperator(ch))
            {
                if (token != string.init)
                {
                    result ~= new Token(2, token.to!double);
                    token   = "";
                }

                result ~= new Token(1, ch.to!string());
            }
            else
            {
                token ~= ch;
            }
        }

        if (token != string.init)
        {
            result ~= new Token(2, token.to!double);
        }

        return result;
    }

    bool isOperator(char ch)
    {
        return inArray!char("[]+-*/^", ch);
    }

    bool isCalcOperator(string ch)
    {
        return ((ch == "+") || (ch == "-") || (ch == "*") || (ch == "/") || (ch == "^"));
    }

    int getPriority(string operator)
    {
        if ((operator == "[") || (operator == "]"))
        {
            return 4;
        }

        if (operator == "^")
        {
            return 3;
        }

        if ((operator == "*") || (operator == "/"))
        {
            return 2;
        }

        if ((operator == "+") || (operator == "-"))
        {
            return 1;
        }

        return -1;
    }

    double calc(double numerial1, double numerial2, string operator)
    {
        if (operator == "+")
        {
            return numerial1 + numerial2;
        }
        else if (operator == "-")
        {
            return numerial1 - numerial2;
        }
        else if (operator == "*")
        {
            return numerial1 * numerial2;
        }
        else if (operator == "/")
        {
            return numerial1 / numerial2;
        }
        else if (operator == "^")
        {
            return numerial1^^numerial2;
        }

        assert(0, "Syntax error in expression, Unknown operator: " ~ operator);
    }
}
