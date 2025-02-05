local l=require"lib"
local calc=require"calc"
local ns=require"numsym"
local the,help=l.settings[[
rulr2.lua : a small range learner
(c) 2024, Tim Menzies, timm@ieee.org, BSD-2 license

Options:
  -b --big     a big number                    = 1E30
  -F --far     how far to search for 'far'     = 0.9
  -k --k       low class frequency kludge      = 1
  -m --m       low attribute frequency kludge  = 2
  -s --seed    random number seed              = 1234567891
  -t --train   train data                      = ../data/misc/auto93.csv ]]

local NUM  = ns.NUM  -- info on numeric columns
local SYM  = ns.SYM  -- info on symbolic columns
local DATA = {} -- place to store all the columns 
local COLS = {} -- factory to make NUMs and SYMs

-----------------------------------------------------------------------------------------
function DATA.new(  names,      cols)
  cols = names and COLS.new(names) or nil
  return l.is(DATA,{rows={},  cols=cols}) end

function DATA:read(file) for   row in l.csv(file) do self:add(row) end; return self end
function DATA:load(lst)  for _,row in pairs(lst)  do self:add(row) end; return self end

function DATA:add(row)
  if   self.cols
  then l.push(self.rows, self.cols:add(row))
  else self.cols = COLS.new(row) end 
  return self end

function DATA:mids(cols)
  return l.map(cols or self.cols.y, function(col) return l.rnd(col:mid()) end) end

----------------------------------------------------------------------------------------
function COLS.new(names,     self,col)
  self = l.is(COLS, { all={}, x={}, y={}, names=names })
  for pos,name in pairs(names) do self:newColumn(name,pos) end
return self end

function COLS:newColumn(name,pos,    col)
  col = ns.COL(name,pos)
  l.push(self.all,col)
  if not name:find"X$" then
    l.push(name:find"[-+!]$" and self.y or self.x, col) end end

function COLS:add(row,        x)
  for _,cols in pairs{self.x, self.y} do
    for _,col in pairs(cols) do
       x = row[col.pos]
       if x ~= "?" then col:add(row[col.pos]) end end end
  return row end

-----------------------------------------------------------------------------------------
-- Once we have rows, we can talk likelihood of rows

function DATA:like(row,nall,nh,    prior,x,like,out)
  out, prior = 0, (#self.rows + the.k) / (nall + the.k*nh)
  for _,col in pairs(self.cols.x) do
    x = row[col.pos]
    if x ~= "?" then
      like = col:like(x,prior)
      if like > 0 then out = out + math.log(like) end end end
  return out + math.log(prior) end 

function SYM:like(x, prior)
  return ((self.has[x] or 0) + the.m*prior)/(self.n +the.m) end

function NUM:like(x,_,      nom,denom)
  local mu, sd =  self:mid(), (self:div() + 1E-30)
  nom   = 2.718^(-.5*(x - mu)^2/(sd^2))
  denom = (sd*2.5 + 1E-30)
  return  nom/denom end

-----------------------------------------------------------------------------------------
-- Once we have rows, we can talk distance between rows or rows

function DATA:dist(row1,row2,  cols)
  return calc.minkowski(row1,row2,the.p, cols or self.cols.x) end

function SYM:dist(x,y)
  return  (x=="?" and y=="?" and 1) or (x==y and 0 or 1) end

function NUM:dist(x,y)
  if x=="?" and y=="?" then return 1 end
  x,y = self:norm(x), self:norm(y)
  if x=="?" then x=y<.5 and 1 or 0 end
  if y=="?" then y=x<.5 and 1 or 0 end
  return math.abs(x-y) end

function DATA:neighbors(rowx,  rows, cols,     d)
  d = function(row) return self:dist(row,rowx,cols) end
  return l.sort(rows or self.rows, function(row2,row3) return d(row2) < d(row3) end) end

--------------------------------------------------------------------------------
math.randomseed(the.seed)
return {the=the, lib=l,DATA=DATA,SYM=SYM,NUM=NUM,COLS=COLS}
