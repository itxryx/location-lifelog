const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { LocationClient, SearchPlaceIndexForPositionCommand } = require('@aws-sdk/client-location');

const dynamoClient = new DynamoDBClient();
const dynamodb = DynamoDBDocumentClient.from(dynamoClient);
const locationClient = new LocationClient();

const tableName = 'location-lifelog';
const placeIndexName = 'location-lifelog-place-index';

exports.handler = async (event) => {
  try {
    const body = JSON.parse(event.body);

    const _unixtime_ms = Date.now(); // UTC
    const unixtime_s = Math.floor(_unixtime_ms / 1000); // 秒精度に調整

    const latitude = parseFloat(body.latitude);
    const longitude = parseFloat(body.longitude);

    if (latitude === undefined || longitude === undefined) {
      throw new Error("required: latitude, longitude");
    }

    if (isNaN(latitude) || isNaN(longitude)) {
      throw new Error("not a number: latitude, longitude");
    }

    // Amazon Location Serviceを使用した逆ジオコーディング
    const locationParams = {
      IndexName: placeIndexName,
      Position: [longitude, latitude]
    };

    const locationCommand = new SearchPlaceIndexForPositionCommand(locationParams);
    const locationResponse = await locationClient.send(locationCommand);

    // 住所を取得
    const full_address = locationResponse.Results[0]?.Place?.Label || "unknown address";

    const half_width_full_address = full_address
        .replace(/　/g, " ") // 全角スペースを半角に
        .replace(/－/g, "-") // 全角ハイフンを半角に
        .replace(/[Ａ-Ｚａ-ｚ０-９！-～]/g, char => String.fromCharCode(char.charCodeAt(0) - 0xfee0)); // 全角英数字と記号を半角に

    // DynamoDBにデータを保存
    const params = {
      TableName: tableName,
      Item: {
        datetime: unixtime_s,
        full_address: half_width_full_address,
        latitude: latitude,
        longitude: longitude
      }
    };

    await dynamodb.send(new PutCommand(params));

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'success',
        data: params.Item,
      })
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'error',
        error: error.message
      })
    };
  }
};