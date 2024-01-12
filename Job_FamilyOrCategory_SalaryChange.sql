CREATE DEFINER=`root`@`localhost` PROCEDURE `JobFamily/Category_SalaryINC/DEC`(IN timelabel VARCHAR(60), IN geolabel VARCHAR(200), IN label VARCHAR(200))
proc_Exit:BEGIN    

    DECLARE table_check_sql VARCHAR(1000);

    -- Check if the sql_log table exists, and create it if it doesn't    
    CREATE TABLE IF NOT EXISTS sql_log (id INT AUTO_INCREMENT PRIMARY KEY,log_message TEXT, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP    );

    -- Initialize table_count to 0    
    SET @table_count = 0;

    -- Check if the table generate_stats.json_daily_run exists    
    SET @table_check_sql = CONCAT('SELECT COUNT(*) FROM generate_stats.json_daily_run INTO @table_count');

    PREPARE table_check_stmt FROM @table_check_sql;
    EXECUTE table_check_stmt;
    DEALLOCATE PREPARE table_check_stmt;

    -- If the table is empty, log a message and exit   
IF @table_count = 0 THEN
        INSERT INTO sql_log (log_message) VALUES ('The table generate_stats.json_daily_run is empty');
        LEAVE proc_Exit;
END IF;

	-- Input validation for timeLabel
IF timeLabel NOT IN ('quarter', 'biannual','annual') THEN
        -- Handle invalid timeLabel input
        INSERT INTO sql_log (log_message) VALUES ('Invalid timeLabel input.It should be either quarter,biannual or annual.');
        LEAVE proc_Exit;
END IF;
#INSERT INTO sql_log (log_message) VALUES (CONCAT('Debug: geolabel = ', geolabel));

IF geolabel NOT REGEXP '^(@region=[A-Za-z_\\s\\-]*,?@country=[A-Za-z_\\s\\-]*,|@country=[A-Za-z_\\s\\-]*,?@region=[A-Za-z_\\s\\-]*,|@country=[A-Za-z_\\s\\-]*,|@region=[A-Za-z_\\s\\-]*,?)$' THEN
   -- Handle invalid geoLabel input
      INSERT INTO sql_log (log_message) VALUES ('Invalid geoLabel input or missing a comma at the end of geolabel');   
LEAVE proc_Exit;      
END IF;  
  	
IF Label NOT IN ('job-family', 'job-category') THEN
        -- Handle invalid geoLabel input
        INSERT INTO sql_log (log_message) VALUES ('Invalid Label input.It should be either job-family or job-category');
        LEAVE proc_Exit;
    END IF;

SET @inputString = geolabel;
SET @pair1 =SUBSTRING(@inputstring,LOCATE('@region=',@inputstring));
SET @value1 =SUBSTRING(@pair1,LOCATE('=',@pair1)+1,(LOCATE(',',@pair1)-1)-LOCATE('=',@pair1));

SET @pair2 =SUBSTRING(@inputstring,LOCATE('@country=',@inputstring));
SET @value2 = SUBSTRING(@pair2,LOCATE('=',@pair2)+1,(LOCATE(',',@pair2)-1)-LOCATE('=',@pair2));

SET @region=INSTR(geoLabel, '@region=');
SET @country =INSTR(geoLabel, '@country=');


IF timelabel='quarter' or timelabel='biannual' or timelabel = 'annual' THEN
 IF label= 'job-category' OR label = 'job-family' THEN
SET @SQL_QUERY='SELECT year,';
   IF @region > 0 AND @country = 0 THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region');
   ELSEIF @region > 0 AND @country > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country');
   ELSEIF @region = 0 AND @country > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country ');  
   END IF;
   
  CASE WHEN label='job-category' THEN  
		SET @SQL_QUERY = CONCAT(@SQL_QUERY,',`job-category`,');
        WHEN label='job-family' THEN  
		SET @SQL_QUERY = CONCAT(@SQL_QUERY,',`job-family`,');
    END CASE;    
	  
   Case when timelabel='quarter' THEN
       SET @SQL_QUERY = CONCAT(@SQL_QUERY,
         'ROUND(AVG(CASE WHEN QUARTER(`date`) = 1 THEN avg_salary  END), 3) AS "Quarter_1", 
         ROUND(AVG(CASE WHEN QUARTER(`date`) = 2 THEN avg_salary  END), 3) AS "Quarter_2",
        ROUND(AVG(CASE WHEN QUARTER(`date`) = 3 THEN avg_salary END), 3) AS "Quarter_3", 
         ROUND(AVG(CASE WHEN QUARTER(`date`) = 4 THEN avg_salary  END), 3) AS "Quarter_4" ');
         
  WHEN timelabel='biannual'  THEN 
	SET @SQL_QUERY = CONCAT(@SQL_QUERY,
         'ROUND((IFNULL(AVG(CASE WHEN QUARTER(`date`) = 1 THEN avg_salary  END),0) + IFNULL(AVG(CASE WHEN QUARTER(`date`) = 2 THEN avg_salary   END),0)) / 2, 3) AS "BiAnnual_Q1_Q2",
		  ROUND((IFNULL(AVG(CASE WHEN QUARTER(`date`) = 3 THEN avg_salary  END),0) + IFNULL(AVG(CASE WHEN QUARTER(`date`) = 4 THEN avg_salary  END),0)) / 2, 3) AS "BiAnnual_Q3_Q4" ');
  
  WHEN timelabel='annual' THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,       
         'ROUND((IFNULL(AVG(CASE WHEN QUARTER(`date`) = 1 THEN avg_salary END),0) + IFNULL(AVG(CASE WHEN QUARTER(`date`) = 2 THEN avg_salary END),0)
                +IFNULL(AVG(CASE WHEN QUARTER(`date`) = 3 THEN avg_salary END),0) + IFNULL(AVG(CASE WHEN QUARTER(`date`) = 4 THEN avg_salary END),0)) / 4, 3) AS "Annual"');
	
 END CASE;       
  
    SET @SQL_QUERY=CONCAT(@SQL_QUERY,' FROM generate_stats.json_daily
    WHERE region !="none" and avg_salary !=0 and `job-family` != "" and ');
   
   IF @region > 0 AND @country = 0  THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY, 'region = ?');
ELSEIF @region > 0 AND @country > 0  THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY, 'region = ? AND country = ?');
ELSEIF @region = 0 AND @country > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY, 'country = ?');
END IF;
   
   #IF @region > 0 AND @country = 0  THEN 
    #SET @SQL_QUERY = CONCAT(@SQL_QUERY,' region=@value1');
   #ELSEIF @region > 0 AND @country > 0  THEN
    #SET @SQL_QUERY = CONCAT(@SQL_QUERY,' region=@value1 and country= @value2');
   #ELSEIF @region = 0 AND @country > 0 THEN
    #SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country=@value2 ');  
   #END IF;
    
    
-- Add the GROUP BY clauses based on conditions
SET @SQL_QUERY = CONCAT(@SQL_QUERY, ' GROUP BY year, ');
   IF @region > 0 AND @country = 0 THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region');
   ELSEIF @region > 0 AND @country > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country');
   ELSEIF @region = 0 AND @country > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country');  
   END IF;
   
   CASE WHEN label='job-category' THEN  
		SET @SQL_QUERY = CONCAT(@SQL_QUERY,',`job-category`');
        WHEN label='job-family' THEN  
		SET @SQL_QUERY = CONCAT(@SQL_QUERY,',`job-family`');
    END CASE;  
    
SET @SQL_QUERY = CONCAT(@SQL_QUERY, ' ORDER BY  ');
   IF @region > 0 AND @country = 0 THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region');
   ELSEIF @region > 0 AND @country > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country');
   ELSEIF @region = 0 AND @country > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country');  
   END IF;
   
   CASE WHEN label='job-category' THEN  
		SET @SQL_QUERY = CONCAT(@SQL_QUERY,',`job-category`,');
        WHEN label='job-family' THEN  
		SET @SQL_QUERY = CONCAT(@SQL_QUERY,',`job-family`,');   
    END CASE;  
SET @SQL_QUERY = CONCAT(@SQL_QUERY, 'year DESC');    
  
INSERT INTO sql_log (log_message) VALUES (@SQL_QUERY);

PREPARE dynamicQuery1 FROM @SQL_QUERY;
IF @region > 0 AND @country > 0 THEN
    -- Both region and country values are present
    EXECUTE dynamicQuery1 USING @value1, @value2;
ELSEIF @region > 0 THEN
    -- Only region value is present
    EXECUTE dynamicQuery1 USING @value1;
ELSEIF @country > 0 THEN
    -- Only country value is present
    EXECUTE dynamicQuery1 USING @value2;
END IF;
DEALLOCATE PREPARE dynamicQuery1;	
    
 END IF;
 END IF;
 END