
function progressbar(query,value,max,byte)
{var pg=document.querySelector(query),vn=parseInt(value)||0,mn=parseInt(max)||100,fv=byte?String.format('%1024.2mB',value):value,fm=byte?String.format('%1024.2mB',max):max,pc=Math.floor((100/mn)*vn);if(pg){pg.firstElementChild.style.width=pc+'%';pg.setAttribute('title','%s / %s (%d%%)'.format(fv,fm,pc));}}
function renderBox(title,active,childs){childs=childs||[];childs.unshift(L.itemlist(E('span'),[].slice.call(arguments,3)));return E('div',{class:'ifacebox'},[E('div',{class:'ifacebox-head center '+(active?'active':'')},E('strong',title)),E('div',{class:'ifacebox-body left'},childs)]);}
function renderBadge(icon,title){return E('span',{class:'ifacebadge'},[E('img',{src:icon,title:title||''}),L.itemlist(E('span'),[].slice.call(arguments,2))]);}

L.poll(5,L.location(),{status:1},function(x,info)
{
	var e;
	if(e=document.getElementById('localtime'))e.innerHTML=info.localtime;
	if(e=document.getElementById('uptime'))e.innerHTML=String.format('%t',info.uptime);
	if(e=document.getElementById('loadavg'))e.innerHTML=String.format('%.02f, %.02f, %.02f',info.loadavg[0]/65535.0,info.loadavg[1]/65535.0,info.loadavg[2]/65535.0);progressbar('#memtotal',info.memory.free+info.memory.buffered,info.memory.total,true);progressbar('#memfree',info.memory.free,info.memory.total,true);progressbar('#membuff',info.memory.buffered,info.memory.total,true);progressbar('#swaptotal',info.swap.free,info.swap.total,true);progressbar('#swapfree',info.swap.free,info.swap.total,true);progressbar('#conns',info.conncount,info.connmax,false);}
);