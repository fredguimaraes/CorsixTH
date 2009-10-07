--[[ Copyright (c) 2009 Peter "Corsix" Cawley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. --]]

local auto_tokens = {
  [","]  = {"operator", ","},
  ["="]  = {"operator", "="},
  ["<"]  = {"operator", "<"},
  [">"]  = {"operator", ">"},
  ["*"]  = {"operator", "%*"},
  ["->"] = {"operator", "%->"},
  ["("]  = {"("},
  [")"]  = {")"},
}

function tokens_gfind(tokens, ...)
  local pattern = {...}
  local ti = 0
  if type(pattern[1]) == "number" then
    ti = pattern[1] - 1
    table.remove(pattern, 1)
  end
  for i, v in ipairs(pattern) do
    if type(v) == "string" then
      pattern[i] = auto_tokens[v] or {"identifier", v}
    end
  end
  return function()
    local tis
    repeat
      local matched = true
      local adjust = -1
      ti = ti + 1
      tis = {}
      for i, v in ipairs(pattern) do
        if not tokens[ti + i + adjust] then
          return
        end
        matched = false
        if i == 1 and tokens[ti + i + adjust][2] == "whitespace" then
          break
        end
        while tokens[ti + i + adjust][2] == "whitespace" do
          adjust = adjust + 1
          if not tokens[ti + i + adjust] then
            return
          end
        end
        if v[1] and tokens[ti + i + adjust][2] ~= v[1] then
          break
        end
        if v[2] and not tokens[ti + i + adjust][1]:match(v[2]) then
          break
        end
        matched = true
        tis[#tis + 1] = ti + i + adjust
      end
    until matched
    return tokens, unpack(tis)
  end
end

function code(s)
  return "*{{{" .. s .. "}}}*"
end

function map(t, f)
  local t_out = {}
  for k, v in pairs(t) do
    t_out[k] = f(v)
  end
  return t_out
end

function set(t)
  local s = {}
  for i, v in ipairs(t) do
    s[v] = true
  end
  return s
end