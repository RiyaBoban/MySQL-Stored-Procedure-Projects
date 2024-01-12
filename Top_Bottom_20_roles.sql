CREATE DEFINER=`root`@`localhost` PROCEDURE `Top/Bottom20_Roles`(IN timelabel VARCHAR(60), IN geolabel VARCHAR(200), IN label VARCHAR(200))
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
        INSERT INTO sql_log (log_message) VALUES ('Invalid timeLabel input. It should be either quarter,biannual or annual.');
        LEAVE proc_Exit;
END IF;
IF 
    RIGHT(geoLabel, 1) <> ',' THEN
	INSERT INTO sql_log (log_message) VALUES ('Add a comma at the end of geoLabel');
	LEAVE proc_Exit;
END IF;  	
IF Label NOT IN ('Top 20 roles', 'Bottom 20 roles') THEN
        -- Handle invalid geoLabel input
        INSERT INTO sql_log (log_message) VALUES ('Invalid Label input. It should be either Top 20 roles or Bottom 20 roles');
        LEAVE proc_Exit;
    END IF;

SET @inputString = geolabel;
SET @pair1 =SUBSTRING(@inputstring,LOCATE('@region=',@inputstring));
SET @value1 =SUBSTRING(@pair1,LOCATE('=',@pair1)+1,(LOCATE(',',@pair1)-1)-LOCATE('=',@pair1));

SET @pair2 =SUBSTRING(@inputstring,LOCATE('@country=',@inputstring));
SET @value2 = SUBSTRING(@pair2,LOCATE('=',@pair2)+1,(LOCATE(',',@pair2)-1)-LOCATE('=',@pair2));

SET @region=INSTR(geoLabel, '@region=');
SET @country =INSTR(geoLabel, '@country=');

IF timelabel='quarter' or timelabel ='annual'  THEN 
   IF label='Top 20 roles' OR label ='Bottom 20 roles' THEN
    SET @SQL_QUERY1 ='SELECT ';
      IF @region > 0 AND @country = 0 THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' region');
	  ELSEIF @region > 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region,country');
      ELSEIF @region = 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'country ');  
	  END IF;
	SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,',`job-category`, `job-family`, `job-role`,');
    CASE WHEN timelabel ='quarter' THEN
              SET@SQL_QUERY1 = CONCAT(@SQL_QUERY1,'`year`, Quarter,salary_change FROM (');
         WHEN timelabel='annual' THEN
              SET@SQL_QUERY1 = CONCAT(@SQL_QUERY1,'`year`,salary_change FROM (');
     END CASE;
     
	SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'SELECT ');
      IF @region > 0 AND @country = 0 THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' region,');
	  ELSEIF @region > 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region,country,');
      ELSEIF @region = 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'country, ');  
	  END IF;
      
      CASE WHEN timelabel ='quarter' THEN
              SET@SQL_QUERY1 = CONCAT(@SQL_QUERY1,' `year`, quarter(`date`) AS Quarter');
          WHEN timelabel='annual' THEN
              SET@SQL_QUERY1 = CONCAT(@SQL_QUERY1,' `year` ');
        END CASE;
       SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, ', `job-category`, `job-family`, `job-role`, 
                                AVG(Avg_Salary) - LAG(AVG(Avg_Salary)) OVER (PARTITION BY `job-category`, `job-family`, `job-role`,');
        
        IF @region > 0 AND @country = 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, ' region ');
        ELSEIF @region > 0 AND @country > 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, ' region, country ');
        ELSEIF @region = 0 AND @country > 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, ' country ');
        END IF;
        
	CASE WHEN timelabel ='quarter' THEN
        SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' ORDER BY `year`, quarter(`date`)) AS salary_change');
        WHEN timelabel='annual' THEN
        SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' ORDER BY `year`) AS salary_change');
    END CASE;                                           
     
	SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, ' FROM generate_stats.json_daily
                                                WHERE Avg_Salary != 0 AND `job-role` != "" and ');
               
	 IF (@region > 0 AND @country = 0 ) THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' region=@value1 ');
	   ELSEIF (@region > 0 AND @country > 0 ) THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' region=@value1 and country=@value2 ');  
	   ELSEIF (@region = 0 AND @country > 0 ) THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' country=@value2 ');
       END IF;
       
    SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'GROUP BY `job-category`,`job-family`,`job-role`,');
         CASE WHEN timelabel ='quarter' THEN
              SET@SQL_QUERY1 = CONCAT(@SQL_QUERY1,'`year`,quarter(`date`),');
			 WHEN timelabel='annual' THEN
			  SET@SQL_QUERY1 = CONCAT(@SQL_QUERY1,'`year`,');
         END CASE;
         
	   IF @region > 0 AND @country = 0 THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region ) AS Salary_diff');
	   ELSEIF @region > 0 AND @country > 0  THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region,country ) AS Salary_diff');
	   ELSEIF @region = 0 AND @country > 0  THEN  
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'country ) AS Salary_diff');  
       END IF;
    
    SET @SQL_QUERY1 =CONCAT(@SQL_QUERY1,' WHERE salary_change is not null');
    
    CASE WHEN label='Top 20 roles'  THEN    
		SET @SQL_QUERY1 =CONCAT(@SQL_QUERY1, ' ORDER BY salary_change DESC LIMIT 20');
			 WHEN label ='Bottom 20 roles'  THEN
		SET @SQL_QUERY1 =CONCAT(@SQL_QUERY1, ' ORDER BY salary_change ASC LIMIT 20');    
	END CASE ;
  END IF; 
 
ELSEIF timelabel ='biannual'  THEN 
   IF label='Top 20 roles' OR label ='Bottom 20 roles' THEN
    SET @SQL_QUERY1 ='SELECT ';
      IF @region > 0 AND @country = 0 THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region ');
	  ELSEIF @region > 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region,country ');
      ELSEIF @region = 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'country ');  
	  END IF;
	SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,',`job-category`, `job-family`, `job-role`, `month`, `year`,ROUND((avg_salary - prev_6months ),3) as Prev_6_months_salary_change
											FROM(SELECT  `job-category`,`job-family`, `job-role`,avg_salary,`month`, `year`,');
        
	  IF @region > 0 AND @country = 0 THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region');
	  ELSEIF @region > 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region,country');
      ELSEIF @region = 0 AND @country > 0 THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'country ');  
	  END IF;
      
       SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, ' ,AVG(Avg_Salary)  OVER (PARTITION BY `job-category`, `job-family`, `job-role`,');
        
        IF @region > 0 AND @country = 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'region ');
        ELSEIF @region > 0 AND @country > 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'region, country ');
        ELSEIF @region = 0 AND @country > 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'country ');
        END IF;
    SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'ORDER BY `year` , `month` ROWS  between 6 preceding AND 1  preceding ) AS prev_6months FROM ( SELECT ');
      IF @region > 0 AND @country = 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'region ');
        ELSEIF @region > 0 AND @country > 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'region, country ');
        ELSEIF @region = 0 AND @country > 0 THEN
            SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'country ');
        END IF;
    
    SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, ', `job-category`,`job-family` , `job-role`,  month, year,avg( Avg_Salary) as avg_salary FROM generate_stats.json_daily
                                                WHERE Avg_Salary != 0 AND `job-role` != "" and ');
               
	 IF (@region > 0 AND @country = 0 ) THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region=@value1 ');
	   ELSEIF (@region > 0 AND @country > 0 ) THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region=@value1 and country=@value2 ');  
	   ELSEIF (@region = 0 AND @country > 0 ) THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'country=@value2 ');
       END IF;
       
    SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1, 'GROUP BY `month`, `year`,`job-category`,`job-family`,`job-role`,');
            
	   IF @region > 0 AND @country = 0 THEN 
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region)');
	   ELSEIF @region > 0 AND @country > 0  THEN
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'region,country)');
	   ELSEIF @region = 0 AND @country > 0  THEN  
		SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,'country)');  
       END IF;
    
    SET @SQL_QUERY1 =CONCAT(@SQL_QUERY1,'  AS Avg_Salary_Table ) AS `Table`  WHERE (avg_salary - prev_6months ) is not null');
    CASE WHEN label='top 20 roles' THEN
    SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' ORDER BY  Prev_6_months_salary_change DESC LIMIT 20;');
        WHEN label='Bottom 20 roles' THEN
    SET @SQL_QUERY1 = CONCAT(@SQL_QUERY1,' ORDER BY  Prev_6_months_salary_change ASC LIMIT 20;');
    END CASE;

END IF;
END IF;   


PREPARE dynamicQuery1 FROM @SQL_QUERY1;
EXECUTE dynamicQuery1;

DEALLOCATE PREPARE dynamicQuery1;	

END