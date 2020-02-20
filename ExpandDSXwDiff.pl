#!/usr/bin/perl -w
use File::Path qw(mkpath);
use File::Compare;

#Initialise variables
my $beginJobLine=0;
my $tempFile='temp.dsx';
my $beginJob=0;
my $file='';
my $category='';
my $lineCount=0;
my $header='';
my $projectDSX=$ARGV[0];
my $projectName='';
my $logFile='logFile.txt';

#Functions for printing out logging information
sub OpenLog{
	open(FLOG,">$logFile") or die "Couldn't create log file";
}
sub PrintLog{
	my $logEntry = shift;
	my $time = localtime();
	print $time.$logEntry."\n";
	#print FLOG $time.$logEntry."\n";
	print FLOG $logEntry."\n";
}
sub CloseLog{
	close(FLOG);
}
#Function for comparing two DSX files checking for difference
sub FileCheck{
	my $file1 = shift;
	my $file2 = shift;
	
	#open file handle to each file for comparison
	open(F1,"<$file1") or die "Couldn't open temp file";
	open(F2,"<$file2") or return -1; #Don't bother doing compare because file doesn't exist
	#dump file DSX header from the file handles as we do not care about changes here
	while(<F1>){
		if(/END HEADER/){
			last;
		}
	}
	while(<F2>){
		if(/END HEADER/){
			last;
		}
	}
	#compare files and return status of difference - uses the file handles
	return compare(*F1,*F2);
}
#Extract the header from the main DSX file to cat onto individual files
sub generateHeader{
	open(FI,"<$projectDSX") or die "Input file not found";
	PrintLog (": File Loaded");
	while(<FI>)
	{
		$header.= $_;
		if(/ServerName "(.*)"/ || /ToolInstanceID "(.*)"/)
		{
			$projectName .= $1.'\\';
		}
		if(/END HEADER/){
			PrintLog (": Header End");
			last;
		}
	}
	close(FI);
}

#Start of script to process DSX
OpenLog();
PrintLog(": Expanding $projectDSX");
PrintLog(": Extracting header");
generateHeader();
PrintLog ": Extracted header";

open(FI,"<$projectDSX") or die "Input file not found";
PrintLog ": Parsing project dsx file";
while(<FI>)
{
	#This will skip over any parts of a DSX that contain an executble
	if(/BEGIN DSEXECJOB/){
		while(<FI>){
			if(/END DSEXECJOB/){
				last;
			}
		}
	}
	#We are still within a job
	if($beginJob==1)
	{
		print FO $_;
		#Get job name which is one line after the BEGIN
		if((/Identifier ".*"/) && ($lineCount==0)){
			/Identifier "(.*)"/;
			$file=$1;
			$lineCount=1
		}
		#Get the job category which will form the directory structure of the project
		if(/Category ".*"/){
			/Category "(.*)"/;
			$category = $1.'\\';                                                            
		}
	}
	#We have found the start of a new job
	if(/BEGIN DSJOB|BEGIN DSPARAMETERSETS|BEGIN DSROUTINES|BEGIN DSSHAREDCONTAINER|BEGIN DSTABLEDEFS/){
		$beginJob=1;
		$lineCount=0;
		open(FO,">$tempFile") or die "Cannot open output file\n";
		print FO $header;
		print FO $_;
		next; #We can skip to the next line immediately;
	}
	#We have found the end of a job
	if(/END DSJOB|END DSPARAMETERSETS|END DSROUTINES|END DSSHAREDCONTAINER|END DSTABLEDEFS/){
		if(/END DSPARAMETERSETS/){
			$category = 'Parameters\\';
			$file = 'ParameterSets';
		}
		if(/END DSROUTINES/){
			$category = 'Routines\\';
			$file = 'Routines';
		}
		if(/END DSTABLEDEFS/){
			$category = 'TableDefinitions\\';
			$file = 'TableDefinitions';
		}
		$beginJob=0;
		close(FO);
		my $fullFile = $projectName.$category.$file.'.dsx';
		$fullFile =~ s/\\*\\/\//g; 
		$fullFile =~ s/ /_/g;
		my $path = $projectName.$category;
		$path =~ s/\\*\\/\//g;
		$path =~ s/ /_/g;		
		mkpath $path;
		PrintLog(": $fullFile");
		#Comapare temp file and the previous file
		my $fileCheck = FileCheck($tempFile,$fullFile);
		$line_count = `wc -l < temp.dsx`;
		PrintLog ("\nLines: $line_count");
		if($fileCheck == 0){
			PrintLog ": Job Found - No changes since last check";
			next;
		}elsif($fileCheck == -1){
			PrintLog ": Job Not Found - DSX Created";
			rename $tempFile, $fullFile;
		}else{
			PrintLog ": Job Found - Change detected since last check File updated";
			rename $tempFile, $fullFile;
		}
		
	}
}
unlink($tempFile);
close(FI);
CloseLog();
exit;