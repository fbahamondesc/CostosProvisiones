/*********************************************************************************   
 Nombre Procedimiento : BxO_Calculo_Costo_Provisiones  
 Descripción          : Procedimiento que realiza el calculo de los costos   
         de provisiones del libro de obra.   
 Fecha de Creación    : 2020-01-17  
 Cliente              : Icafal    
 Creado por           : Francisco Bahamondes  
**********************************************************************************/
IF OBJECT_ID ( '[BxO_Calculo_Costo_Provisiones]', 'P' ) IS NOT NULL 
    DROP PROCEDURE BxO_Calculo_Costo_Provisiones;
GO

CREATE PROCEDURE dbo.BxO_Calculo_Costo_Provisiones
	@periodo char(6)
	,@emp_cod varchar(5)
AS

BEGIN

		SELECT dbo.LOB_EMPRESA.emp_cod
		,dbo.LOB_OBRA.obra_cod
		,LIBRO_OBRA.InvtId
		,LIBRO_OBRA.Sub_cod
		,LIBRO_OBRA.monto
		,CONVERT(VARCHAR(4), BxO_DATA.dbo.DOC_APDoc.InvcDate, 102) + CONVERT(VARCHAR(2), BxO_DATA.dbo.DOC_APDoc.InvcDate, 110) periodo_ant
		,BxO_DATA.dbo.BO_Periodos.periodo
	INTO #TABLATEMP
	FROM dbo.LOB_EMPRESA
	INNER JOIN (
		SELECT a.Emp_cod
			,a.Obra_cod
			,a.Sub_cod
			,a.InvtId
			,a.periodo
			,b.Aux_Glosa
			,a.tipomov
			,a.DrAmt - a.Cramt AS monto
			,CASE 
				WHEN b.modulo = 'AP'
					THEN b.Aux_apdoc_ID
				ELSE b.Aux_apdoc_cl_id
				END AS Apdoc_ID
		FROM dbo.LOB_BORRADOR a
		INNER JOIN dbo.LOB_BORRADOR_DETALLE b ON a.bor_id = b.bor_id
				
		UNION
				
		SELECT a.Emp_cod
			,a.Obra_cod
			,a.Sub_cod
			,a.InvtId
			,a.periodo
			,b.Aux_Glosa
			,a.tipomov
			,a.DrAmt - a.Cramt AS monto
			,CASE 
				WHEN b.modulo = 'AP'
					THEN b.Aux_apdoc_ID
				ELSE b.Aux_apdoc_cl_id
				END AS Apdoc_ID
		FROM dbo.LOB_CERRADO a
		INNER JOIN dbo.LOB_CERRADO_DETALLE b ON a.Cer_id = b.Cer_id
	) AS LIBRO_OBRA ON (LIBRO_OBRA.Emp_cod = dbo.LOB_EMPRESA.emp_cod)
	INNER JOIN dbo.LOB_OBRA ON (
			dbo.LOB_OBRA.emp_cod = LIBRO_OBRA.Emp_cod
			AND dbo.LOB_OBRA.obra_cod = LIBRO_OBRA.Obra_cod
			)
	LEFT OUTER JOIN dbo.LOB_PERIODO_V ON (
			LIBRO_OBRA.Emp_cod = dbo.LOB_PERIODO_V.emp_cod
			AND LIBRO_OBRA.periodo = dbo.LOB_PERIODO_V.periodo
			)
	INNER JOIN dbo.BO_Periodos ON (
			dbo.BO_Periodos.periodo = dbo.LOB_PERIODO_V.periodo
			AND dbo.BO_Periodos.CpnyID = dbo.LOB_PERIODO_V.emp_cod
			)
	LEFT OUTER JOIN BxO_DATA.dbo.DOC_APDoc ON (BxO_DATA.dbo.DOC_APDoc.apdoc_id = LIBRO_OBRA.Apdoc_ID)
	WHERE (
			dbo.LOB_EMPRESA.Activa = 1
			AND dbo.LOB_EMPRESA.Grupo in ('Icafal', 'Icil')
			AND dbo.LOB_EMPRESA.emp_cod = @emp_cod
			AND BxO_DATA.dbo.BO_Periodos.periodo >= @periodo
			AND CONVERT(VARCHAR(4), BxO_DATA.dbo.DOC_APDoc.InvcDate, 102) + CONVERT(VARCHAR(2), BxO_DATA.dbo.DOC_APDoc.InvcDate, 110) < LIBRO_OBRA.periodo
			AND LIBRO_OBRA.tipomov <> 'CL-A'
			AND LIBRO_OBRA.Aux_Glosa IN (
				'B.Honorarios'
				,'Fact.Compra'
				,'Fact.Compra Elect.'
				,'Fact.Elect.'
				,'Factura'
				,'Liquidación Factura'
				,'N.Cred.Compra'
				,'N.Cred.Elect.'
				,'N.Deb.Elect.'
				,'Nota Crédito'
				,'Nota Crédito Factura'
				,'Nota de Debito Elect.'
				,'Nota Débito'
				,'Nota Débito OT'
				)
			)

	UPDATE BCP
	SET BCP.costo_provisiones = TT.MONTO
	FROM BO_Calculo_Provisiones BCP 
	JOIN (
		SELECT TT.emp_cod
			,TT.obra_cod
			,TT.InvtId
			,TT.Sub_cod
			,TT.periodo
			,SUM(TT.monto) AS MONTO
		FROM #TABLATEMP TT
		GROUP BY TT.emp_cod
			,TT.obra_cod
			,TT.InvtId
			,TT.Sub_cod
			,TT.periodo
		) TT ON TT.emp_cod = BCP.CpnyID
		AND TT.InvtId = BCP.InsumoLOB
		AND TT.periodo = BCP.PerPost
		AND TT.Sub_cod = BCP.PCO_Subcta
		AND TT.obra_cod = BCP.obra_cod
		AND TT.periodo = BCP.PerPost

	DROP TABLE #TABLATEMP
END