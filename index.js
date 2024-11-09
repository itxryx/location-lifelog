const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient();
const dynamodb = DynamoDBDocumentClient.from(client);
const tableName = 'location-lifelog';

exports.handler = async (event) => {
  try {
    const body = JSON.parse(event.body);

    const _unixtime_ms = Date.now(); // UTC
    const unixtime_s = Math.floor(_unixtime_ms / 1000); // 秒精度に調整

    const _raw_address = body.full_address || "";
    const full_address = _raw_address.replace(/\r?\n/g, ' ');

    const latitude = body.latitude;
    const longitude = body.longitude;

    if (latitude === undefined || longitude === undefined) {
      throw new Error("required: latitude, longitude");
    }

    const params = {
      TableName: tableName,
      Item: {
        datetime: unixtime_s,
        full_address: full_address,
        latitude: Number(latitude),
        longitude: Number(longitude)
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
