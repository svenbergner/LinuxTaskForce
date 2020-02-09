// JavaScript to generate a compact date representation

//
// format date as dd-mmm-yy
// example: 12-Jan-99
//
function date_ddmmmyy(date)
{
  var d = date.getDate();
  var m = date.getMonth() + 1;
  var y = date.getFullYear();
  var h = date.getHours();
  var min = date.getMinutes();
  var sec = date.getSeconds();

  // handle different year values 
  // returned by IE and NS in 
  // the year 2000.
  //if(y >= 2000)
  //{
  //  y -= 2000;
  //}
  //if(y >= 100)
  //{
  //  y -= 100;
  //}

  // could use splitString() here 
  // but the following method is 
  // more compatible
  var mmm = 
    ( 1==m)?'Januar':( 2==m)?'Februar':(3==m)?'M&auml;rz':
    ( 4==m)?'April':( 5==m)?'Mai':(6==m)?'Juni':
    ( 7==m)?'Juli':( 8==m)?'August':(9==m)?'September':
    (10==m)?'Oktober':(11==m)?'November':'Dezember';

  return " " + (d<10?"0"+d:d) + "." +  (m<10?"0"+m:m) + "." + y + " - " 
             + (h<10?"0"+h:h) + ":" + (min<10?"0"+min:min) + ":" + (sec<10?"0"+sec:sec) + " ";
}


//
// get last modified date of the 
// current document.
//
function date_lastmodified()
{
  var lmd = document.lastModified;
  var s   = "Unbekannt";
  var d1;

  // check if we have a valid date
  // before proceeding
  if(0 != (d1=Date.parse(lmd)))
  {
    s = "" + date_ddmmmyy(new Date(d1));
  }

  return s;
}

//
// finally display the last modified date
// as DD.MM.YYYY
//
document.writeln( date_lastmodified() );

// End
