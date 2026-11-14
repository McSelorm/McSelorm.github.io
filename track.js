// Grow With Selorm: simple, private visit counter.
// Saves: which page, phone or computer, where the visitor came from, and a random visitor code.
// It does NOT save names, IP addresses or anything typed into forms.
(function(){
  var URL = 'https://jxwxdibeyrdkkuqikmgj.supabase.co/rest/v1/activity';
  var KEY = 'sb_publishable_roZXn9Mp076MSzbOwrA9Hg_LNwJvpcR';

  function visitorId(){
    try{
      var v = localStorage.getItem('gws_visitor');
      if(!v){ v = 'v' + Math.random().toString(36).slice(2, 12); localStorage.setItem('gws_visitor', v); }
      return v;
    }catch(e){ return 'v-private'; }
  }
  function from(){
    try{
      var r = document.referrer;
      if(!r) return 'Direct / WhatsApp';
      var h = new URL(r).hostname.replace(/^www\./, '');
      if(h === location.hostname) return null; // moving inside the site
      if(/whatsapp/.test(h)) return 'WhatsApp';
      if(/facebook|fb\.com/.test(h)) return 'Facebook';
      if(/google/.test(h)) return 'Google';
      if(/linkedin|lnkd/.test(h)) return 'LinkedIn';
      if(/t\.co|twitter|x\.com/.test(h)) return 'X (Twitter)';
      if(/instagram/.test(h)) return 'Instagram';
      return h.slice(0, 100);
    }catch(e){ return null; }
  }
  function device(){
    var u = navigator.userAgent || '';
    if(/iPad|Tablet/i.test(u)) return 'Tablet';
    if(/Mobi|Android|iPhone/i.test(u)) return 'Phone';
    return 'Computer';
  }

  window.gwsTrack = function(event, detail){
    try{
      var body = { visitor: visitorId(), event: event || 'visit', page: (location.pathname || '/').slice(0, 100), device: device() };
      if(detail) body.detail = String(detail).slice(0, 200);
      if(event === 'visit' || !event){ var f = from(); if(f) body.referrer = f; }
      fetch(URL, { method: 'POST', keepalive: true,
        headers: { 'apikey': KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal' },
        body: JSON.stringify(body) }).catch(function(){});
    }catch(e){}
  };

  // Do not count Selorm's own visits once he has logged in as admin on this device.
  var skip = false; try{ skip = localStorage.getItem('gws_is_admin') === '1'; }catch(e){}
  if(!skip) window.gwsTrack('visit');
})();
