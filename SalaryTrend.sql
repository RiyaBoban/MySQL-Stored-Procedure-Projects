CREATE DEFINER=`root`@`localhost` PROCEDURE `SalaryTrend`(IN timeLabel VARCHAR(60),
    IN geoLabel VARCHAR(2000))
proc_Exit:BEGIN   
    DECLARE table_check_sql VARCHAR(1000);

    -- Check if the sql_log table exists, and create it if it doesn't    
    CREATE TABLE IF NOT EXISTS sql_log (id INT AUTO_INCREMENT PRIMARY KEY,log_message TEXT, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP    );

    -- Initialize table_count to 0    
    SET @table_count = 0;

    -- Check if the table generate_stats.json_daily exists    
    SET @table_check_sql = CONCAT('SELECT COUNT(*) FROM generate_stats.json_daily INTO @table_count');

    PREPARE table_check_stmt FROM @table_check_sql;
    EXECUTE table_check_stmt;
    DEALLOCATE PREPARE table_check_stmt;


    -- If the table is empty, log a message and exit   
IF @table_count = 0 THEN
        INSERT INTO sql_log (log_message) VALUES ('The table generate_stats.json_daily is empty');
        LEAVE proc_Exit;
END IF;

	-- Input validation for timeLabel
IF 
        timeLabel NOT IN ('quarter','biannual', 'annual') THEN
        INSERT INTO sql_log (log_message) VALUES ('Invalid timeLabel input');
        LEAVE proc_Exit;
END IF;  
 
IF 
    RIGHT(geoLabel, 1) <> ',' THEN
	INSERT INTO sql_log (log_message) VALUES ('Add a comma at the end of geoLabel');
	LEAVE proc_Exit;
END IF; 

SET @inputString = geolabel;
SET @pair1 =SUBSTRING(@inputstring,LOCATE('@region=',@inputstring));
SET @value1 =SUBSTRING(@pair1,LOCATE('=',@pair1)+1,(LOCATE(',',@pair1)-1)-LOCATE('=',@pair1));

SET @pair2 =SUBSTRING(@inputstring,LOCATE('@country=',@inputstring));
SET @value2 = SUBSTRING(@pair2,LOCATE('=',@pair2)+1,(LOCATE(',',@pair2)-1)-LOCATE('=',@pair2));

SET @pair3 =SUBSTRING(@inputstring,LOCATE('@company=',@inputstring));
SET @value3 = SUBSTRING(@pair3,LOCATE('=',@pair3)+1,(LOCATE(',',@pair3)-1)-LOCATE('=',@pair3));

SET @pair4 =SUBSTRING(@inputstring,LOCATE('@role=',@inputstring));
SET @value4 =SUBSTRING(@pair4,LOCATE('=',@pair4)+1,(LOCATE(',',@pair4)-1)-LOCATE('=',@pair4));

SET @region=INSTR(geoLabel, '@region=');
SET @country =INSTR(geoLabel, '@country=');
SET @company=INSTR(geoLabel, '@company=');
SET @role= INSTR(geoLabel, '@role=');


IF timelabel='quarter' or timelabel='biannual' or timelabel = 'annual' THEN
SET @SQL_QUERY='SELECT year,';
   IF @region > 0 AND @country = 0 AND @company = 0 AND @role = 0 THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region');
   ELSEIF @region > 0 AND @country > 0 AND @company = 0 AND @role = 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country');
   ELSEIF @region > 0 AND @country > 0 AND @company > 0 AND @role = 0 THEN  
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,company');
   ELSEIF @region > 0 AND @country > 0 AND @company > 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,company,`job-role`');
   ELSEIF @region > 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,`job-role`');
   ELSEIF @region > 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,`job-role` '); 
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role = 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country ');  
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country,`job-role`'); 
   ELSEIF @region = 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'`job-role` ');  
   END IF;
   
   Case when timelabel='quarter' THEN
       SET @SQL_QUERY = CONCAT(
        @SQL_QUERY,',',
         'ROUND(AVG(CASE WHEN QUARTER(`date`) = 1 THEN avg_salary  END), 3) AS "Quarter_1", 
         ROUND(AVG(CASE WHEN QUARTER(`date`) = 2 THEN avg_salary  END), 3) AS "Quarter_2",
        ROUND(AVG(CASE WHEN QUARTER(`date`) = 3 THEN avg_salary END), 3) AS "Quarter_3", 
         ROUND(AVG(CASE WHEN QUARTER(`date`) = 4 THEN avg_salary  END), 3) AS "Quarter_4" ', '');
         
  WHEN timelabel='biannual' THEN 
	SET @SQL_QUERY = CONCAT(
        @SQL_QUERY,',',
         'ROUND((IFNULL(AVG(CASE WHEN QUARTER(`date`) = 1 THEN avg_salary  END),0)+ IFNULL(AVG(CASE WHEN QUARTER(`date`) = 2 THEN avg_salary   END),0)) / 2, 3) AS "BiAnnual_Q1_Q2",
		  ROUND((IFNULL(AVG(CASE WHEN QUARTER(`date`) = 3 THEN avg_salary  END),0) + IFNULL(AVG(CASE WHEN QUARTER(`date`) = 4 THEN avg_salary  END),0)) / 2, 3) AS "BiAnnual_Q3_Q4" ', '');
   WHEN timelabel='annual' THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY, ',',        
         'ROUND((IFNULL(AVG(CASE WHEN QUARTER(`date`) = 1 THEN avg_salary END),0) + IFNULL(AVG(CASE WHEN QUARTER(`date`) = 2 THEN avg_salary END),0)
                +IFNULL(AVG(CASE WHEN QUARTER(`date`) = 3 THEN avg_salary END),0)+IFNULL(AVG(CASE WHEN QUARTER(`date`) = 4 THEN avg_salary END),0)) / 4, 3) AS "Annual"');
	
 END CASE;       
  
    SET @SQL_QUERY=CONCAT(@SQL_QUERY,'FROM generate_stats.json_daily
    WHERE region !="none" and avg_salary !=0 and ');
    
    IF (@region > 0 AND @country = 0 AND @company = 0 AND @role = 0) THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,' region= ?');
   ELSEIF (@region > 0 AND @country > 0 AND @company = 0 AND @role = 0) THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,' region= ? and country= ?');
   ELSEIF (@region > 0 AND @country > 0 AND @company > 0 AND @role = 0) THEN  
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,' region= ? and country= ? and company= ?');
   ELSEIF (@region > 0 AND @country > 0 AND @company > 0 AND @role > 0) THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,' region= ? and country= ? and company= ? and `job-role`= ?');
   ELSEIF @region > 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region= ? and country= ? and `job-role`= ?');
   ELSEIF @region > 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region= ? and `job-role`= ?');
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role = 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country= ?');  
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country= ? and `job-role`= ?'); 
   ELSEIF @region = 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'`job-role`= ?');   
   END IF;
    
    
-- Add the GROUP BY clauses based on conditions
SET @SQL_QUERY = CONCAT(@SQL_QUERY, ' GROUP BY year, ');
   IF @region > 0 AND @country = 0 AND @company = 0 AND @role = 0 THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region');
   ELSEIF @region > 0 AND @country > 0 AND @company = 0 AND @role = 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country');
   ELSEIF @region > 0 AND @country > 0 AND @company > 0 AND @role = 0 THEN  
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,company');
   ELSEIF @region > 0 AND @country > 0 AND @company > 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,company,`job-role`');
   ELSEIF @region > 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,`job-role`'); 
   ELSEIF @region > 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,`job-role`'); 
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role = 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country');  
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country,`job-role` '); 
   ELSEIF @region = 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'`job-role` ');  
   END IF;

SET @SQL_QUERY = CONCAT(@SQL_QUERY, ' ORDER BY  ');
	IF @region > 0 AND @country = 0 AND @company = 0 AND @role = 0 THEN 
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region');
   ELSEIF @region > 0 AND @country > 0 AND @company = 0 AND @role = 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country');
   ELSEIF @region > 0 AND @country > 0 AND @company > 0 AND @role = 0 THEN  
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,company');
   ELSEIF @region > 0 AND @country > 0 AND @company > 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,company,`job-role`');
   ELSEIF @region > 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,country,`job-role`'); 
   ELSEIF @region > 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'region,`job-role`'); 
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role = 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country');  
   ELSEIF @region = 0 AND @country > 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'country,`job-role` '); 
   ELSEIF @region = 0 AND @country = 0 AND @company = 0 AND @role > 0 THEN
    SET @SQL_QUERY = CONCAT(@SQL_QUERY,'`job-role` ');  
   END IF;
SET @SQL_QUERY = CONCAT(@SQL_QUERY, ', year DESC');   
INSERT INTO sql_log (log_message) VALUES (@SQL_QUERY);
PREPARE dynamicQuery FROM @SQL_QUERY;

IF @region > 0 AND @country > 0 AND @company > 0 AND @role > 0 THEN
	EXECUTE dynamicQuery USING @value1, @value2, @value3, @value4;
ELSEIF @region > 0 AND @country > 0 AND @company > 0 THEN
	EXECUTE	dynamicQuery USING @value1, @value2, @value3;
ELSEIF @region > 0 AND @country > 0 AND @role > 0 THEN
	EXECUTE	dynamicQuery USING @value1, @value2, @value4;
ELSEIF @region > 0 AND @country > 0 THEN
	EXECUTE	dynamicQuery USING @value1, @value2;
ELSEIF @region > 0 AND @role > 0 THEN
	EXECUTE	dynamicQuery USING @value1, @value4;
ELSEIF @country > 0 AND @role > 0 THEN
	EXECUTE	dynamicQuery USING @value2, @value4;    
ELSEIF @region > 0 THEN
	EXECUTE	dynamicQuery USING @value1;    
ELSEIF @country > 0 THEN
	EXECUTE	dynamicQuery USING  @value2;   
ELSEIF @role > 0 THEN
	EXECUTE	dynamicQuery USING @value4;   
END IF;
    
DEALLOCATE PREPARE dynamicQuery;

        
end if;
END