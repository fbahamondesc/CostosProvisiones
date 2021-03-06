/*********************************************************************************** 
	Nombre Procedimiento  : BxO_Calculo_Provisiones
	Descripción           : Procedimiento que realiza el calculo de los provisiones.
	Fecha de Creación     : 7
	Fecha de Modificacion : 2020-01-17 
	Cliente               : Icafal  
	Modificado por        : Francisco Bahamondes
	Detalles              : Se agrega procedimiento para calcular los costos de
							provisiones
************************************************************************************/
ALTER PROCEDURE BxO_Calculo_Provisiones
AS
DECLARE @sName AS VARCHAR(100);
DECLARE @sPeriodo VARCHAR(6);
DECLARE @sCompania VARCHAR(5);
DECLARE @sObra VARCHAR(5);
DECLARE @sInsumo VARCHAR(6);
DECLARE @sPeriodoZ VARCHAR(6);
DECLARE @sPeriodoCalculado VARCHAR(6);
DECLARE @sCompaniaZ VARCHAR(5);
DECLARE @sObraZ VARCHAR(5);
DECLARE @sInsumoZ VARCHAR(6);
DECLARE @nMontoAcum NUMERIC(25);
DECLARE @nMonto NUMERIC(25);
DECLARE @iMes AS INT;
DECLARE @iReg AS INT;
DECLARE @iAnioDate AS INT;
DECLARE @iAnioCal AS INT;
DECLARE @sAnioInicio AS VARCHAR(4);
DECLARE @sPCO_cuenta AS VARCHAR(20)
DECLARE @sPCO_Subcta AS VARCHAR(20)
DECLARE @curCalculo AS CURSOR;
DECLARE @TablaPaso TABLE (
	CpnyID VARCHAR(5)
	,PerPost VARCHAR(6)
	,Anio VARCHAR(4)
	,PCO_cuenta VARCHAR(20)
	,PCO_Subcta VARCHAR(20)
	,Monto NUMERIC(25, 0)
	,MontoAcum NUMERIC(25, 0)
	,obra_cod VARCHAR(5)
	,InsumoLOB VARCHAR(6)
	,Periodo VARCHAR(6)
	,AnioProv VARCHAR(4)
	,ObraProv VARCHAR(5)
	,InsumoProv VARCHAR(6)
	,E NUMERIC(25, 0)
	,CLG NUMERIC(25, 0)
	,PG NUMERIC(25, 0)
	,PI NUMERIC(25, 0)
	);

BEGIN
	SET NOCOUNT ON;
	SET @sAnioInicio = '2018'
	SET @iAnioDate = convert(INT, substring(convert(VARCHAR(8), getdate(), 112), 1, 4))

	INSERT INTO @TablaPaso
	SELECT CpnyID
		,PerPost
		,Substring(PerPost, 1, 4) Ani
		,isnull(PCO_cuenta, '') PCO_cuenta
		,isnull(PCO_Subcta, '') PCO_Subcta
		,isnull(Monto, 0) Monto
		,0 MontoAcum
		,isnull(obra_cod, '') obra_cod
		,isnull(InsumoLOB, '') InsumoLOB
		,isnull(Periodo, '') Periodo
		,isnull(SUBSTRING(periodo, 1, 4), '') AnioProv
		,isnull(ObraOrigen, '') ObraOrigen
		,isnull(InsumoProv, '') InsumoProv
		,isnull(E, 0) E
		,isnull(CLG, 0) Clg
		,isnull(PG, 0) Pg
		,isnull(PI, 0) Pi
	FROM (
		SELECT DISTINCT bvg.CpnyID
			,bvg.PerPost
			,SUBSTRING(bvg.PerPost, 1, 4) AS Anio
			,SUBSTRING(lcv.cyc_ctacto, 2, 1) + '00' PCO_cuenta
			,Substring(lcv.cyc_ctacto, 2, 3) PCO_Subcta
			,SUM(bvg.DrAmt - bvg.CrAmt) AS Monto
			,lov.obra_cod
			,bvg.user1 AS InsumoLOB
		FROM BxO_DATA.dbo.LOB_OBRA lov
		INNER JOIN BxO_DATA.dbo.BO_GlTran bvg ON (
				bvg.CpnyID = lov.emp_cod
				AND bvg.User2 = lov.obra_cod
				AND bvg.CpnyID IN (
					'0201'
					,'0202'
					,'0206'
					)
				AND bvg.Acct LIKE '4%'
				AND bvg.PerPost >= @sAnioInicio + '01'
				)
		--And bvg.PerPost >= '2018' + '01'
		LEFT OUTER JOIN dbo.LOB_CYC_HISTORICO lcv ON (
				bvg.CpnyID = lcv.cyc_emp
				AND bvg.User1 = lcv.cyc_ins
				AND bvg.User2 = lcv.cyc_obra
				AND lcv.cyc_ul_vigente = '1'
				)
		GROUP BY bvg.CpnyID
			,bvg.PerPost
			,SUBSTRING(bvg.PerPost, 1, 4)
			,SUBSTRING(lcv.cyc_ctacto, 2, 1) + '00'
			,Substring(lcv.cyc_ctacto, 2, 3)
			,lov.obra_cod
			,bvg.user1
		) AS A
	LEFT JOIN (
		SELECT *
		FROM (
			SELECT pp.Periodo
				,pp.[OBRA Origen] ObraOrigen
				,pp.TIPO
				,pp.Insumo AS InsumoProv
				,SUM(isnull(pp.monto, 0)) AS Monto
			FROM po_provisiones pp
			GROUP BY Periodo
				,[Obra Origen]
				,TIPO
				,Insumo
			) AS sou
		PIVOT(AVG(Monto) FOR TIPO IN (
					E
					,CLG
					,PG
					,PI
					)) AS PO_provisiones
		) AS B ON (
			A.obra_cod = B.ObraOrigen
			AND A.PerPost = B.Periodo
			AND A.InsumoLOB = B.InsumoProv
			)

	--------------------------------------------------------------------------------------------------------------
	--UNION
	--------------------------------------------------------------------------------------------------------------
	INSERT INTO @TablaPaso
	SELECT isnull(A.CpnyID, B.empresa) CpnyID
		,isnull(A.PerPost, B.Periodo) Periodo
		,isnull(Substring(A.PerPost, 1, 4), Substring(B.Periodo, 1, 4)) Anio
		,isnull(A.PCO_Cuenta, '') PCO_Cuenta
		,isnull(A.PCO_Subcta, '') PCO_Subcta
		,isnull(A.Monto, 0) Monto
		,0 MontoAcum
		,isnull(A.obra_cod, isnull(B.ObraOrigen, '')) obra_cod
		,isnull(A.InsumoLOB, isnull(B.Insumoprov, '')) InsumoLOB
		,isnull(Periodo, '') Periodo
		,isnull(Substring(Periodo, 1, 4), '') AnioProv
		,isnull(ObraOrigen, '') ObraOrigen
		,isnull(Insumoprov, '') Insumoprov
		,isnull(B.E, 0) E
		,isnull(B.CLG, 0) Clg
		,isnull(B.PG, 0) Pg
		,isnull(B.PI, 0) Pi
	FROM (
		SELECT DISTINCT bgv.CpnyID
			,bgv.PerPost
			,'' Anio
			,Substring(lcv.cyc_ctacto, 2, 1) + '00' PCO_cuenta
			,Substring(lcv.cyc_ctacto, 2, 3) PCO_Subcta
			,SUM(bgv.DrAmt - bgv.CrAmt) AS Monto
			,lov.obra_cod
			,bgv.user1 AS InsumoLOB
		FROM BxO_DATA.dbo.LOB_OBRA lov
		INNER JOIN BxO_DATA.dbo.BO_GlTran bgv ON (
				bgv.CpnyID = lov.emp_cod
				AND bgv.User2 = lov.obra_cod
				AND bgv.CpnyID IN (
					'0201'
					,'0202'
					,'0206'
					)
				AND bgv.Acct LIKE '4%'
				AND bgv.PerPost >= @sAnioInicio + '01'
				)
		--And bgv.PerPost >= '2018' + '01'
		LEFT OUTER JOIN LOB_CYC_HISTORICO lcv ON (
				bgv.CpnyID = lcv.cyc_emp
				AND bgv.User1 = lcv.cyc_ins
				AND bgv.User2 = lcv.cyc_obra
				AND lcv.cyc_ul_vigente = '1'
				)
		GROUP BY bgv.CpnyID
			,bgv.PerPost
			,SUBSTRING(bgv.PerPost, 1, 4)
			,Substring(lcv.cyc_ctacto, 2, 1) + '00'
			,Substring(lcv.cyc_ctacto, 2, 3)
			,lov.obra_cod
			,bgv.user1
		) A
	RIGHT JOIN (
		SELECT *
		FROM (
			SELECT Periodo
				,(
					SELECT emp_cod
					FROM lob_obra
					WHERE obra_cod = PO_provisiones.[Obra Origen]
					) empresa
				,'' Anio
				,[Obra Origen] ObraOrigen
				,TIPO
				,Insumo AS Insumoprov
				,SUM(isnull(monto, 0)) AS Monto
			FROM po_provisiones
			GROUP BY Periodo
				,[Obra Origen]
				,TIPO
				,Insumo
			) AS sou
		PIVOT(AVG(Monto) FOR TIPO IN (
					E
					,CLG
					,PG
					,PI
					)) AS PO_provisiones
		) AS B ON (
			A.obra_cod = B.ObraOrigen
			AND A.PerPost = B.Periodo
			AND A.InsumoLOB = B.Insumoprov
			)
	WHERE a.CpnyID IS NULL

	--------------------------------------------------------------------------------------------------------------
	--Calculo
	--------------------------------------------------------------------------------------------------------------
	--Select * from @TablaPaso order by CpnyID, obra_cod, InsumoLOB, PerPost
	SET @sCompaniaZ = ''
	SET @sObraZ = ''
	SET @sInsumoZ = ''
	SET @iMes = 1
	SET @nMontoAcum = 0
	SET @iReg = 0
	SET @curCalculo = CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY
	FOR

	SELECT CpnyID
		,obra_cod
		,InsumoLOB
	FROM @TablaPaso
	ORDER BY CpnyID
		,obra_cod
		,InsumoLOB

	OPEN @curCalculo

	FETCH NEXT
	FROM @curCalculo
	INTO @sCompania
		,@sObra
		,@sInsumo

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @sCompania != @sCompaniaZ
		BEGIN
			SET @sCompaniaZ = @sCompania
			SET @sObraZ = @sObra
			SET @sInsumoZ = @sInsumo
			SET @nMontoAcum = 0
			SET @iMes = 1
			SET @iAnioCal = convert(INT, @sAnioInicio)
			SET @sPCO_cuenta = ''
			SET @sPCO_Subcta = ''
		END
		ELSE
		BEGIN
			IF @sObra != @sObraZ
			BEGIN
				SET @sObraZ = @sObra
				SET @sInsumoZ = @sInsumo
				SET @nMontoAcum = 0
				SET @iAnioCal = convert(INT, @sAnioInicio)
				SET @iMes = 1
				SET @sPCO_cuenta = ''
				SET @sPCO_Subcta = ''
			END
			ELSE
			BEGIN
				IF @sInsumoZ != @sInsumo
				BEGIN
					SET @sInsumoZ = @sInsumo
					SET @nMontoAcum = 0
					SET @iAnioCal = convert(INT, @sAnioInicio)
					SET @iMes = 1
					SET @sPCO_cuenta = ''
					SET @sPCO_Subcta = ''
				END
			END
		END

		WHILE @iAnioCal <= @iAnioDate
		BEGIN
			WHILE @iMes < 13
			BEGIN
				SELECT @iReg = count(0)
				FROM @TablaPaso
				WHERE 1 = 1
					AND CpnyID = @sCompaniaZ
					AND obra_cod = @sObraZ
					AND InsumoLOB = @sInsumoZ
					AND PerPost = Convert(VARCHAR(4), @iAnioCal) + Right('0' + Convert(VARCHAR(2), @iMes), 2)

				IF @iReg = 0
				BEGIN
					INSERT INTO @TablaPaso (
						CpnyID
						,obra_cod
						,InsumoLOB
						,PerPost
						,Anio
						,PCO_cuenta
						,PCO_Subcta
						,Monto
						,MontoAcum
						,E
						,CLG
						,PG
						,PI
						,Periodo
						,AnioProv
						,ObraProv
						,InsumoProv
						)
					VALUES (
						@sCompaniaZ
						,@sObraZ
						,@sInsumoZ
						,Convert(VARCHAR(4), @iAnioCal) + Right('0' + Convert(VARCHAR(2), @iMes), 2)
						,Substring(Convert(VARCHAR(4), @iAnioCal), 1, 4)
						,''
						,''
						,0
						,isnull(@nMontoAcum, 0)
						,0
						,0
						,0
						,0
						,''
						,''
						,''
						,''
						)
				END
				ELSE
				BEGIN
					SELECT @nMonto = isnull(Monto, 0)
						,@sPCO_cuenta = PCO_cuenta
						,@sPCO_Subcta = PCO_Subcta
					FROM @TablaPaso
					WHERE 1 = 1
						AND CpnyID = @sCompaniaZ
						AND obra_cod = @sObraZ
						AND InsumoLOB = @sInsumoZ
						AND PerPost = Convert(VARCHAR(4), @iAnioCal) + Right('0' + Convert(VARCHAR(2), @iMes), 2)

					--
					SET @nMontoAcum = @nMonto + @nMontoAcum

					--
					UPDATE @TablaPaso
					SET MontoAcum = @nMontoAcum
					WHERE 1 = 1
						AND CpnyID = @sCompaniaZ
						AND obra_cod = @sObraZ
						AND InsumoLOB = @sInsumoZ
						AND PerPost = Convert(VARCHAR(4), @iAnioCal) + Right('0' + Convert(VARCHAR(2), @iMes), 2)
				END

				SET @iMes = @iMes + 1
			END

			IF @sPCO_cuenta != ''
			BEGIN
				UPDATE @TablaPaso
				SET PCO_cuenta = @sPCO_cuenta
					,PCO_Subcta = @sPCO_Subcta
				WHERE 1 = 1
					AND CpnyID = @sCompaniaZ
					AND obra_cod = @sObraZ
					AND InsumoLOB = @sInsumoZ
					--And PerPost = Convert( varchar(4), @iAnioCal ) +  Right( '0' + Convert( varchar(2), @iMes), 2)
			END

			SET @iAnioCal = @iAnioCal + 1
			SET @iMes = 1
			SET @nMontoAcum = 0
		END

		FETCH NEXT
		FROM @curCalculo
		INTO @sCompania
			,@sObra
			,@sInsumo
	END

	-- Elimina los datos antes de cargarlos nuevamente desde cero
	DELETE
	FROM BO_Calculo_Provisiones

	-- inserta los datos 
	INSERT INTO BO_Calculo_Provisiones
	SELECT CpnyID
		,PerPost
		,Anio
		,PCO_cuenta
		,PCO_Subcta
		,Monto
		,MontoAcum
		,obra_cod
		,InsumoLOB
		,Periodo
		,AnioProv
		,ObraProv
		,InsumoProv
		,E
		,CLG
		,PG
		,PI
		,0
	FROM @TablaPaso
	ORDER BY CpnyID
		,obra_cod
		,InsumoLOB
		,PerPost

	EXEC BxO_Calculo_Costo_Provisiones '201801', '0201'
	EXEC BxO_Calculo_Costo_Provisiones '201801', '0202'
	EXEC BxO_Calculo_Costo_Provisiones '201801', '0206'
END