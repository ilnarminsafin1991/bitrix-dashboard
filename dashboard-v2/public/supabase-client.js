// supabase-client.js — REST-клиент Supabase (без npm)
(function(){
  const cfg = window.APP_CONFIG || {};
  const URL = cfg.SUPABASE_URL || '';
  const KEY = cfg.SUPABASE_ANON_KEY || '';

  window.sb = {
    _token: null,
    _user: null,

    headers(){
      return {
        'apikey': KEY,
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this._token || KEY}`,
        'Prefer': 'return=representation'
      };
    },

    async signIn(email, password){
      const r = await fetch(`${URL}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: {'apikey': KEY, 'Content-Type': 'application/json'},
        body: JSON.stringify({email, password})
      });
      const d = await r.json();
      if(d.access_token){
        this._token = d.access_token;
        this._user = d.user;
        sessionStorage.setItem('sb_token', d.access_token);
        sessionStorage.setItem('sb_user', JSON.stringify(d.user));
      }
      return d;
    },

    async signOut(){
      try{
        await fetch(`${URL}/auth/v1/logout`, {method:'POST', headers: this.headers()});
      }catch(e){}
      this._token = null; this._user = null;
      sessionStorage.removeItem('sb_token');
      sessionStorage.removeItem('sb_user');
    },

    restoreSession(){
      const t = sessionStorage.getItem('sb_token');
      const u = sessionStorage.getItem('sb_user');
      if(t){ this._token = t; this._user = u ? JSON.parse(u) : null; }
      return !!t;
    },

    getUser(){ return this._user || (sessionStorage.getItem('sb_user') ? JSON.parse(sessionStorage.getItem('sb_user')) : null); },

    async select(table, query=''){
      const r = await fetch(`${URL}/rest/v1/${table}${query}`, {headers: this.headers()});
      if(!r.ok){ const e=await r.json(); throw new Error(e.message||r.status); }
      return r.json();
    },

    async insert(table, data){
      const r = await fetch(`${URL}/rest/v1/${table}`, {
        method: 'POST', headers: this.headers(),
        body: JSON.stringify(Array.isArray(data)?data:[data])
      });
      if(!r.ok){ const e=await r.json(); throw new Error(e.message||r.status); }
      return r.json();
    },

    async upsert(table, data){
      const r = await fetch(`${URL}/rest/v1/${table}`, {
        method: 'POST',
        headers: {...this.headers(), 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: JSON.stringify(Array.isArray(data)?data:[data])
      });
      if(!r.ok){ const e=await r.json(); throw new Error(e.message||r.status); }
      return r.json();
    },

    async del(table, match){
      const qs = Object.entries(match).map(([k,v])=>`${k}=eq.${encodeURIComponent(v)}`).join('&');
      const r = await fetch(`${URL}/rest/v1/${table}?${qs}`, {method:'DELETE', headers: this.headers()});
      return r.status === 204 ? [] : r.json();
    },

    async getUserRole(){
      const user = this.getUser();
      if(!user) return null;
      try{
        const d = await this.select('profiles', `?id=eq.${user.id}`);
        return Array.isArray(d) && d[0] ? d[0].role : 'viewer';
      }catch(e){ return 'viewer'; }
    }
  };
})();
