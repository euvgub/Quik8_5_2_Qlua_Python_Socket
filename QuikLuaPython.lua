stopped = false            -- Остановка файла
socket = require("socket") -- Указатель для работы с sockets
json = require( "json" ) -- Указатель для работы с json
IPAddr = "127.0.0.1"       --IP Адрес
IPPort = 3587		   --IP Port	 
sender = nil		   --Укзатель на коннектор
send = nil		   --Указатель на процедуру отправки сообщения
connect = nil		   --Указатель на процедуру подключения к серверу
all_trd_indx = 0	   --Текущий индекс для переданных записей таблицы всех сделок
all_ord_indx = 0
all_stop_ord_indx = 0
all_my_trades_indx = 0
inited = false		   --Для проверки вызова OnAllTrade перед main

-- Функция вызывается перед вызовом main
function OnInit(path)
--  sender = assert(socket.connect(IPAddr, IPPort));
  sender = socket.udp()
  sender:setpeername(IPAddr, IPPort)
  --Выводим сообщение в квике, что есть подключение
  message(string.format("Connection success. IP: %s; Port: %d\n", IPAddr, IPPort), 1);
  sender:send("<qsrt>\n");
end;

-- Функция вызывается перед остановкой скрипта
function OnStop(signal)
  sender:send("<qstp>\n");
  stopped = true; -- Остановили исполнение кода 
end;

-- Функция вызывается перед закрытием квика
function OnClose()
  sender:send("<qcls>\n");
  stopped = true; -- закрыли квик, надо остановить исполнение кода
end;

-- Функция вызвается при изменении стакана

function OnQuote(class, seccode)
  if stopped then return; end
  local sec = getSecurityInfo(class, seccode);
  local price = 0;
  local level2 = getQuoteLevel2(class, seccode); --Получаем стакан
  --сначала загружаем бид, потом аск
  local bidstr = " {"
  if type(level2["bid"]) == "table" then
  	for index, bid in ipairs(level2["bid"]) do
  	  bidstr = bidstr..bid["price"]..":"..bid["quantity"]..","
  	end
  end;
  local askstr = ""
  if type(level2["offer"]) == "table" then 
    for index, ask in ipairs(level2["offer"]) do
	  askstr = askstr..ask["price"]..":-"..ask["quantity"]..","
    end
  end;
  local str = "2 "..seccode..bidstr..askstr.."}\n";
  sender:send(str)
end;

--User trades functions
function formatmytrade (status, trade)
  all_my_trades_indx = all_my_trades_indx + 1
  return status.." "..trade["sec_code"].." "..trade["trade_num"].." "..trade["order_num"].." "..trade["flags"].." \""..trade["account"].."\" "..trade["price"].." "..trade["qty"].." "..trade["value"].." \""..trade["brokerref"].."\" "..trade["datetime"]["day"].."."..trade["datetime"]["month"].."."..trade["datetime"]["year"].." "..trade["datetime"]["hour"]..":"..trade["datetime"]["min"]..":"..trade["datetime"]["sec"].." "..trade["trans_id"].."\n"
end;

function OnTrade(trade)
  if (not inited) or (stopped) then return; end;
  sender:send (formatmytrade (8, trade));
end;

function sendallmytrades()
  local count = getNumberOf("trades");
  local index = 0
  for index=0,count - 1 do
  	if stopped then return false; end;
  	sender:send (formatmytrade (8, getItem("trades", index)));
  end;
  return true;
end;

--User stop orders functions
function formatstoporder (status, order)
  all_stop_ord_indx = all_stop_ord_indx + 1
  return status.." "..order["sec_code"].." "..order["trans_id"].." "..order["order_num"].." "..order["flags"].." \""..order["account"].."\" "..order["price"].." "..order["condition_price"].." "..order["qty"].." "..order["balance"].." \""..order["brokerref"].."\" "..order["ordertime"].."\n"
end;

function OnStopOrder (order)
  if (not inited) or (stopped) then return; end;
  sender:send (formatstoporder (7, order));
end;

function sendallstoporders()
  local count = getNumberOf ("stop_orders");
  local index = 0
  for index=0,count - 1 do
  	if stopped then return false; end;
  	sender:send (formatstoporder (7, getItem ("stop_orders", index)));
  end;
  return true;
end;

function formatorder (status, order)
  all_ord_indx = all_ord_indx + 1
  return status.." "..order["sec_code"].." "..order["trans_id"].." "..order["order_num"].." "..order["flags"].." \""..order["account"].."\" "..order["price"].." "..order["qty"].." "..order["balance"].." "..order["value"].." \""..order["brokerref"].."\" "..order["datetime"]["day"].."."..order["datetime"]["month"].."."..order["datetime"]["year"].." "..order["datetime"]["hour"]..":"..order["datetime"]["min"]..":"..order["datetime"]["sec"].."\n"
--  return status.." "..json.encode(order).."\n"
end;

function OnOrder(order)
  if (not inited) or (stopped) then return; end;
  sender:send (formatorder (6, order));
end;

function sendallorders()
  local count = getNumberOf("orders");
  local index = 0
  for index=0,count - 1 do
  	if stopped then return false; end;
  	sender:send (formatorder (6, getItem("orders", index)));
  end;
  return true;
end;

function OnAllTrade(trade)
  if (not inited) or (stopped) then return; end;
  --Отправляем сделку
  sender:send(formattrade1(1, trade));
end;

function formattrade1(status, trade)
  all_trd_indx = all_trd_indx + 1 -- Увеличиваем счетчик кол-ва 
  --Формируем запись для передачи
  return status.." "..trade["sec_code"].." "..all_trd_indx.." "..trade["trade_num"].." "..trade["price"].." "..trade["flags"].." "..trade["qty"].." "..trade["datetime"]["day"].."."..trade["datetime"]["month"].."."..trade["datetime"]["year"].." "..trade["datetime"]["hour"]..":"..trade["datetime"]["min"]..":"..trade["datetime"]["sec"].."."..trade["datetime"]["ms"].."\n"
--[[  trade_num NUMBER  Идентификатор сделки
flags NUMBER  Набор битовых флагов
price NUMBER  Цена
qty NUMBER  Количество
value NUMBER  Объем сделки
accruedint  NUMBER  Накопленный купонный доход
yield NUMBER  Доходность
settlecode  STRING  Код расчетов
reporate  NUMBER  Ставка РЕПО
repovalue NUMBER  Сумма РЕПО
repo2value  NUMBER  Объем сделки выкупа РЕПО
repoterm  NUMBER  Срок РЕПО в днях
sec_code  STRING  Код инструмента
class_code  STRING  Код класса
datetime  TABLE Дата и время
]]
end;

--Загрузка обезличенных сделок
function sendalltrades()
  local count = getNumberOf("all_trades");
  sender:send("4 "..count.."\n");
  local index = 0
  for index=0,count - 1 do
  	if stopped then return false; end;
  	sender:send(formattrade1(3, getItem("all_trades", index)));
  end; 
  sender:send("5\n");
  return true;
end;

-- Основная функция выполнения скрипта
function main()
  inited = true
  if not stopped then
        local start_time = os.clock()
        if sendalltrades() then
           message("Send all trades history success: " .. tonumber(os.clock() - start_time), 1);
           sendallorders()
           sendallstoporders()
           sendallmytrades()
 	   while not stopped do
  	          sleep(1);
  	    end; --while
  	  end; --if  
  end; --if
  sender:send('<qbye>\n')
  sender:close() --закрываем соединение
  sender=nil
end;