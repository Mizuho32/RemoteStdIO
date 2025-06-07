
(()=>{
const prompt = require("prompt-sync")({ sigint: true });
// const age = prompt("How old are you? ");
// console.log(`You are ${age} years old.`);

const now =  new Date();
const msg = `Msg at ${now}`;
prompt(`continue? ${msg}`)
// return;

fetch("http://localhost:8000/stdout", {
    method: "POST",
    headers: {
          "Content-Type": "application/json"
        },
    body: JSON.stringify({
          message: msg,
					client_id: 'lD714'
        })
});
})()
