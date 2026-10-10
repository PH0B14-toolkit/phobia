import sys
p = "/var/www/html/index.html"
try:
    h = open(p).read()
except Exception as e:
    print("FAIL open:", e); sys.exit(1)

if "ph0b14_err" in h:
    print("SKIP: already injected")
    sys.exit(0)

inject = r'''
<script>
(function(){
  function attach(){
    var f = document.querySelector("form");
    if(!f) return setTimeout(attach, 300);
    f.addEventListener("submit", function(e){
      var inp = document.querySelector("input[type=email],input[name=Email],input[name=email],input#identifierId,input[type=text]");
      if(!inp) return;
      var v = (inp.value || "").trim().toLowerCase();
      var ok = /@(gmail\.com|yahoo\.com)$/.test(v);
      if(!ok){
        e.preventDefault(); e.stopPropagation();
        var old = document.getElementById("ph0b14_err");
        if(old) old.remove();
        var d = document.createElement("div");
        d.id = "ph0b14_err";
        d.style.cssText = "color:#d93025;font-size:13px;margin:8px 0;font-family:Roboto,Arial,sans-serif";
        d.textContent = "Enter a valid Gmail or Yahoo address (example: yourname@gmail.com)";
        inp.parentNode.insertBefore(d, inp.nextSibling);
        return false;
      }
    }, true);
  }
  attach();
})();
</script>
'''

h = h.replace("</body>", inject + "</body>")
open(p, "w").write(h)
print("OK: email validation injected")
