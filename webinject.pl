#!/usr/bin/perl

#    Copyright 2004 Corey Goldberg (corey@test-tools.net)
#
#    This file is part of WebInject.
#
#    WebInject is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    WebInject is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with WebInject; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


use LWP;
use HTTP::Cookies;
use Crypt::SSLeay;
use XML::Simple;
use Time::HiRes 'time','sleep';
#use Data::Dumper;  #to dump hashes for debugging   


$| = 1; #don't buffer output to STDOUT

if ($0 eq 'webinject.pl')  #set flag so we know if it is running standalone or from webinjectgui
    {$gui = 0; engine();}
else
    {$gui = 1;}




#------------------------------------------------------------------
sub engine 
{   
    if ($gui == 1){gui_initial();}
    
    $startruntimer = time();  #timer for entire test run
    $currentdatetime = localtime time;  #get current date and time for results report

    open(HTTPLOGFILE, ">http.log") || die "\nERROR: Failed to open http.log file\n\n";   

    open(RESULTS, ">results.html") || die "\nERROR: Failed to open results.html file\n\n";    
      
    writeinitialhtml();
       
    processcasefile();
    
    #contsruct objects
    $useragent = LWP::UserAgent->new;
    $cookie_jar = HTTP::Cookies->new;
    $useragent->agent('WebInject');  #set http useragent that will show up in webserver logs


    $totalruncount = 0;
    $passedcount = 0;
    $failedcount = 0;
   
    
    foreach (@casefilelist) #process test case files named in config.xml
    {
        $currentcasefile = $_;
        #print "\n$currentcasefile\n\n";
        
        $testnum = 1;
        
        if ($gui == 1){gui_processing_msg();}
        
        convtestcases();
        
        fixsinglecase();
        
        $xmltestcases = XMLin("./$currentcasefile"); #slurp test case file to parse
        #print Dumper($xmltestcases);  #for debug, dump hash of xml   
        #print keys %{$configfile};  #print keys from dereferenced hash
        
        cleancases();
        
        while ($testnum <= $casecount)
        {             
            if ($gui == 1){gui_statusbar();}
            
            $timestamp = time();  #used to replace parsed {timestamp} with real timestamp value
            if ($verifypositivenext) {$verifylater = $verifypositivenext;}  #grab $verifypositivenext string from previous test case (if it exists)
            if ($verifynegativenext) {$verifylaterneg = $verifynegativenext;}  #grab $verifynegativenext string from previous test case (if it exists)
            
            #populate variables with values from testcase file, do substitutions, and revert {AMPERSAND} back to "&"
            $description1 = $xmltestcases->{case}->{$testnum}->{description1}; if ($description1) {$description1 =~ s/{AMPERSAND}/&/g; $description1 =~ s/{TIMESTAMP}/$timestamp/g; if ($gui == 1){gui_tc_descript();}}
            $description2 = $xmltestcases->{case}->{$testnum}->{description2}; if ($description2) {$description2 =~ s/{AMPERSAND}/&/g; $description2 =~ s/{TIMESTAMP}/$timestamp/g;}  
            $method = $xmltestcases->{case}->{$testnum}->{method}; if ($method) {$method =~ s/{AMPERSAND}/&/g; $method =~ s/{TIMESTAMP}/$timestamp/g;}  
            $url = $xmltestcases->{case}->{$testnum}->{url}; if ($url) {$url =~ s/{AMPERSAND}/&/g; $url =~ s/{TIMESTAMP}/$timestamp/g; $url =~ s/{BASEURL}/$baseurl/g;}  
            $postbody = $xmltestcases->{case}->{$testnum}->{postbody}; if ($postbody) {$postbody =~ s/{AMPERSAND}/&/g; $postbody =~ s/{TIMESTAMP}/$timestamp/g;}  
            $verifypositive = $xmltestcases->{case}->{$testnum}->{verifypositive}; if ($verifypositive) {$verifypositive =~ s/{AMPERSAND}/&/g; $verifypositive =~ s/{TIMESTAMP}/$timestamp/g;}  
            $verifynegative = $xmltestcases->{case}->{$testnum}->{verifynegative}; if ($verifynegative) {$verifynegative =~ s/{AMPERSAND}/&/g; $verifynegative =~ s/{TIMESTAMP}/$timestamp/g;}  
            $verifypositivenext = $xmltestcases->{case}->{$testnum}->{verifypositivenext}; if ($verifypositivenext) {$verifypositivenext =~ s/{AMPERSAND}/&/g; $verifypositivenext =~ s/{TIMESTAMP}/$timestamp/g;}  
            $verifynegativenext = $xmltestcases->{case}->{$testnum}->{verifynegativenext}; if ($verifynegativenext) {$verifynegativenext =~ s/{AMPERSAND}/&/g; $verifynegativenext =~ s/{TIMESTAMP}/$timestamp/g;}  
            $logrequest = $xmltestcases->{case}->{$testnum}->{logrequest}; if ($logrequest) {$logrequest =~ s/{AMPERSAND}/&/g; $logrequest =~ s/{TIMESTAMP}/$timestamp/g;}  
            $logresponse = $xmltestcases->{case}->{$testnum}->{logresponse}; if ($logresponse) {$logresponse =~ s/{AMPERSAND}/&/g; $logresponse =~ s/{TIMESTAMP}/$timestamp/g;}  
                         
            print RESULTS "<b>Test:  $currentcasefile - $testnum </b><br>\n";
            print STDOUT "<b>Test:  $currentcasefile - $testnum </b><br>\n";
            if ($description1) 
            {
                print RESULTS "$description1 <br>\n"; 
                print STDOUT "$description1 <br>\n";
            }
            if ($description2) 
            {
                print RESULTS "$description2 <br>\n"; 
                print STDOUT "$description2 <br>\n";
            }
            print RESULTS "<br>\n";
            print STDOUT "<br>\n";
            if ($verifypositive) 
            {
                print RESULTS "Verify: \"$verifypositive\" <br> \n";
                print STDOUT "Verify: \"$verifypositive\" <br> \n";
            }
            if ($verifynegative) 
            {
                print RESULTS "Verify Negative: \"$verifynegative\" <br> \n";
                print STDOUT "Verify Negative: \"$verifynegative\" <br> \n";
            }
            if ($verifypositivenext) 
            {
                print RESULTS "Verify On Next Case: \"$verifypositivenext\" <br> \n";
                print STDOUT "Verify On Next Case: \"$verifypositivenext\" <br> \n";
            }
            if ($verifynegativenext) 
            {
                print RESULTS "Verify Negative On Next Case: \"$verifynegativenext\" <br> \n";
                print STDOUT "Verify Negative On Next Case: \"$verifynegativenext\" <br> \n";
            }
            
            if($method)
            {
                if ($method eq "get")
                {   httpget();  }
                elsif ($method eq "post")
                {   httppost(); }
                else {print STDERR qq|ERROR: bad HTTP Request Method Type, you must use "get" or "post"\n|;}
            }
            else
            {   
                httpget(); #use "get" if no method is specified  
            }  
                
            verify();  #verify result from http response
            
            print RESULTS "Response Time = $latency s<br>\n";
            print STDOUT "Response Time = $latency s<br>\n";
            print RESULTS "<br>\n-------------------------------------------------------<br>\n\n";
            print STDOUT "<br>\n-------------------------------------------------------<br>\n\n";
                        
            $testnum++;
            $totalruncount++;
        }       
    }
    


    $endruntimer = time();
    $totalruntime = (int(10 * ($endruntimer - $startruntimer)) / 10);  #elapsed time rounded to thousandths 


    if ($gui == 1){gui_final();}
    
    
    writefinalhtml();
    
    close(RESULTS);
    close(HTTPLOGFILE);
    

}



#------------------------------------------------------------------
#  SUBROUTINES
#------------------------------------------------------------------
sub writeinitialhtml {

    print RESULTS 
qq(    
<html>
<head>
    <title>WebInject Test Results</title>
    <style type="text/css">
        .title{FONT: 12px verdana, arial, helvetica, sans-serif; font-weight: bold}
        .text{FONT: 10px verdana, arial, helvetica, sans-serif}
        body {background-color: #F5F5F5;
              font-family: verdana, arial, helvetica, sans-serif;
              font-size: 10px;
              scrollbar-base-color: #999999;
              color: #000000;}
    </style>
</head>
<body>
<hr>
-------------------------------------------------------<br>
); 
}
#------------------------------------------------------------------
sub writefinalhtml {

    print RESULTS
qq(    
<br><hr><br>
<b>
Start Time: $currentdatetime <br>
Total Run Time: $totalruntime  seconds <br>
<br>
Test Cases Run: $totalruncount <br>
Verifications Passed: $passedcount <br>
Verifications Failed: $failedcount <br>
</b>
<br>

</body>
</html>
); 
}
#------------------------------------------------------------------
sub httpget {  #send http request and read response
        
    $request = new HTTP::Request('GET',"$url");

    $cookie_jar->add_cookie_header($request);
    
    $starttimer = time();
    $response = $useragent->simple_request($request);
    $endtimer = time();
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  #elapsed time rounded to thousandths 
      
    if ($logrequest && $logrequest eq "yes") {print HTTPLOGFILE $response->as_string; print HTTPLOGFILE "\n\n";} 
    if ($logresponse && $logresponse eq "yes") {print HTTPLOGFILE $request->as_string; print HTTPLOGFILE "\n\n";} 
    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";
}
#------------------------------------------------------------------
sub httppost {  #send http request and read response
    
    $request = new HTTP::Request('POST',"$url");
    $request->content_type('application/x-www-form-urlencoded\n\n');
    $request->content($postbody);
    #print $request->as_string; print "\n\n";
    $cookie_jar->add_cookie_header($request);
    
    $starttimer = time();
    $response = $useragent->simple_request($request);
    $endtimer = time();
    $latency = (int(1000 * ($endtimer - $starttimer)) / 1000);  #elapsed time rounded to thousandths 
     
    if ($logrequest && $logrequest eq "yes") {print HTTPLOGFILE $response->as_string; print HTTPLOGFILE "\n\n";} 
    if ($logresponse && $logresponse eq "yes") {print HTTPLOGFILE $request->as_string; print HTTPLOGFILE "\n\n";} 
    $cookie_jar->extract_cookies($response);
    #print $cookie_jar->as_string; print "\n\n";
}
#------------------------------------------------------------------
sub verify {  #do verification of http response and print PASSED/FAILED to report and UI

    if ($verifypositive)
    {
        if ($response->as_string() =~ /$verifypositive/i)  #verify existence of string in response
        {
            print RESULTS "<b><font color=green>PASSED</font></b><br>\n";
            print STDOUT "<b><font color=green>PASSED</font></b><br>\n";
            if ($gui == 1){gui_status_passed();}
            $passedcount++;
        }
        else
        {
            print RESULTS "<b><font color=red>FAILED</font></b><br>\n";
            print STDOUT "<b><font color=red>FAILED</font></b><br>\n";
            if ($gui == 1){gui_status_failed();}          
            $failedcount++;                
        }
    }



    if ($verifynegative)
    {
        if ($response->as_string() =~ /$verifynegative/i)  #verify existence of string in response
        {
            print RESULTS "<b><font color=red>FAILED</font></b><br>\n";
            print STDOUT "<b><font color=red>FAILED</font></b><br>\n";
            if ($gui == 1){gui_status_failed();}             
            $failedcount++;  
        }
        else
        {
            print RESULTS "<b><font color=green>PASSED</font></b><br>\n";
            print STDOUT "<b><font color=green>PASSED</font></b><br>\n";
            if ($gui == 1){gui_status_passed();}
            $passedcount++;                
        }
    }


    
    if ($verifylater)
    {
        if ($response->as_string() =~ /$verifylater/i)  #verify existence of string in response
        {
            print RESULTS "<b><font color=green>PASSED</font></b> (verification set in previous test case)<br>\n";
            print STDOUT "<b><font color=green>PASSED</font></b> (verification set in previous test case)<br>\n";
            if ($gui == 1){gui_status_passed();}
            $passedcount++;
        }
        else
        {
            print RESULTS "<b><font color=red>FAILED</font></b> (verification set in previous test case)<br>\n";
            print STDOUT "<b><font color=red>FAILED</font></b> (verification set in previous test case)<br>\n";
            if ($gui == 1){gui_status_failed();}             
            $failedcount++;                
        }
        
        $verifylater = '';  #set to null after verification
    }
    
    
    
    if ($verifylaterneg)
    {
        if ($response->as_string() =~ /$verifylaterneg/i)  #verify existence of string in response
        {
            print RESULTS "<b><font color=red>FAILED</font></b> (negative verification set in previous test case)<br>\n";
            print STDOUT "<b><font color=red>FAILED</font></b> (negative verification set in previous test case)<br>\n";
            if ($gui == 1){gui_status_failed();}            
            $failedcount++;  
        }
        else
        {
            print RESULTS "<b><font color=green>PASSED</font></b> (negative verification set in previous test case)<br>\n";
            print STDOUT "<b><font color=green>PASSED</font></b> (negative verification set in previous test case)<br>\n";
            if ($gui == 1){gui_status_passed();}
            $passedcount++;                   
        }
        
        $verifylaterneg = '';  #set to null after verification
    }



    #verify http response code is in the 100-399 range    
    if ($response->as_string() =~ /HTTP\/1.(0|1) (1|2|3)/i)  #verify existance of string in response
    {
        #don't print anything for succesful response codes (100-399) 
    }
    else
    {
        $response->as_string() =~ /(HTTP\/1.)(.*)/i;  
        print RESULTS "<b><font color=red>FAILED </font></b>($1$2)<br>\n"; #($1$2) is http response code if failed
        print STDOUT "<b><font color=red>FAILED </font></b>($1$2)<br>\n"; #($1$2) is http response code if failed
        if ($gui == 1){gui_status_failed();}      
        $failedcount++;            
    }
        
}
#------------------------------------------------------------------
sub processcasefile {  #get test case files to run (from command line or config file) and evaluate constants
    
    undef @casefilelist; #empty the array

    if ($#ARGV < 0) #if testcase filename is not passed on the command line, use config.xml
    {
        open(CONFIG, "config.xml") || die "\nERROR: Failed to open config.xml file\n\n";  #open file handle   
        @configfile = <CONFIG>;  #Read the file into an array
        
        #parse test case file names from config.xml and build array
        foreach (@configfile)
        {
            if (/<testcasefile>/)
            {   
                $firstparse = $';  #print "$' \n\n";
                $firstparse =~ /<\/testcasefile>/;
                $filename = $`;  #string between tags will be in $filename
                #print "$filename \n\n";
                push @casefilelist, $filename;  #add next filename we grab to end of array
            }
        }    
        
        if ($casefilelist[0])
        {
        }
        else
        {
            push @casefilelist, "testcases.xml";  #if no file specified in config.xml, default to testcases.xml
        }
    }
    else # use testcase filename passed on command line 
    {
         push @casefilelist, $ARGV[0];  #if no file specified in config.xml, default to testcases.xml
    }
    
    #print "testcase file list: @casefilelist\n\n";
    
    #grab value for constant: baseurl
    foreach (@configfile)
    {
        if (/<baseurl>/)
        {   
            $firstparse = $';  #print "$' \n\n";
            $firstparse =~ /<\/baseurl>/;
            $baseurl = $`;  #string between tags will be in $baseurl
            #print "$baseurl \n\n";
        }
    }  
    
    close(CONFIG);
}
#------------------------------------------------------------------
sub convtestcases {  #convert ampersands in test cases to {AMPERSAND} so xml parser doesn't puke

    open(XMLTOCONVERT, "$currentcasefile") || die "\nError: Failed to open test case file\n\n";  #open file handle   
    @xmltoconvert = <XMLTOCONVERT>;  #Read the file into an array
    
    $casecount = 0;
    
    foreach (@xmltoconvert)
    { 
        s/&/{AMPERSAND}/g;  #convert ampersands (&) &'s are malformed XML
        
        if ($_ =~ /<case/) #count test cases based on '<case' tag
        {
            $casecount++; 
        }    
    }  

    close(XMLTOCONVERT);   

    open(XMLTOCONVERT, ">$currentcasefile") || die "\nERROR: Failed to open test case file\n\n";  #open file handle   
    print XMLTOCONVERT @xmltoconvert; #overwrite file with converted array
    close(XMLTOCONVERT);
}
#------------------------------------------------------------------
sub fixsinglecase{ #xml parser creates a hash in a different format if there is only a single testcase.  
                   #I add a dummy testcase in this instance to fix this
    
    if ($casecount == 1) 
    {
        open(XMLTOCONVERT, "$currentcasefile") || die "\nError: Failed to open test case file\n\n";  #open file handle   
        @xmltoconvert = <XMLTOCONVERT>;  #Read the file into an array
        
        for(@xmltoconvert)
        { 
            s/<\/testcases>/<case id="2" description1="dummy test case"\/><\/testcases>/g;  #add dummy test case to end of file   
        }       
        close(XMLTOCONVERT);
        
        open(XMLTOCONVERT, ">$currentcasefile") || die "\nERROR: Failed to open test case file\n\n";  #open file handle   
        print XMLTOCONVERT @xmltoconvert; #overwrite file with converted array
        close(XMLTOCONVERT);
    }

}
#------------------------------------------------------------------
sub cleancases {  #cleanup conversions made to file for ampersands and single testcase instance

    open(XMLTOCONVERT, "$currentcasefile") || die "\nError: Failed to open test case file\n\n";  #open file handle   
    @xmltoconvert = <XMLTOCONVERT>;  #Read the file into an array
    
    foreach (@xmltoconvert)
    { 
        s/{AMPERSAND}/&/g;  #convert ampersands (&) &'s are malformed XML
        
        s/<case id="2" description1="dummy test case"\/><\/testcases>/<\/testcases>/g;  #add dummy test case to end of file
    }  

    close(XMLTOCONVERT);   

    open(XMLTOCONVERT, ">$currentcasefile") || die "\nERROR: Failed to open test case file\n\n";  #open file handle   
    print XMLTOCONVERT @xmltoconvert; #overwrite file with converted array
    close(XMLTOCONVERT);
}
#------------------------------------------------------------------