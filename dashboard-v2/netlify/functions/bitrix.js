exports.handler = async (event) => {
  const headers = {'Content-Type':'application/json','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'Content-Type'};
  if(event.httpMethod==='OPTIONS')return{statusCode:200,headers,body:''};
  const WEBHOOK=process.env.BITRIX_WEBHOOK_URL;
  if(!WEBHOOK)return{statusCode:500,headers,body:JSON.stringify({error:'BITRIX_WEBHOOK_URL не задан в Netlify Environment Variables'})};
  try{
    const{method='crm.lead.list',params={}}=JSON.parse(event.body||'{}');
    const base=WEBHOOK.endsWith('/')?WEBHOOK:WEBHOOK+'/';
    const qs=buildQS(params);
    const url=`${base}${method}.json${qs?'?'+qs:''}`;
    const resp=await fetch(url,{cache:'no-store'});
    const data=await resp.json();
    return{statusCode:200,headers,body:JSON.stringify(data)};
  }catch(e){return{statusCode:500,headers,body:JSON.stringify({error:e.message})};}
};
function buildQS(obj,pre=''){
  const p=[];
  for(const[k,v]of Object.entries(obj||{})){
    const key=pre?`${pre}[${k}]`:k;
    if(Array.isArray(v))v.forEach(item=>p.push(`${encodeURIComponent(key)}[]=${encodeURIComponent(item??'')}`));
    else if(v&&typeof v==='object')p.push(buildQS(v,key));
    else p.push(`${encodeURIComponent(key)}=${encodeURIComponent(v??'')}`);
  }
  return p.filter(Boolean).join('&');
}
